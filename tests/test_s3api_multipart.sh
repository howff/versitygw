#!/usr/bin/env bats

# Copyright 2024 Versity Software
# This file is licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

source ./tests/setup.sh
source ./tests/test_s3api_root_inner.sh
source ./tests/util/util_file.sh
source ./tests/util/util_multipart.sh
source ./tests/util/util_tags.sh
source ./tests/commands/get_object.sh
source ./tests/commands/put_object.sh
source ./tests/commands/list_multipart_uploads.sh

# abort-multipart-upload
@test "test_abort_multipart_upload" {
  local bucket_file="bucket-file"

  run create_test_file "$bucket_file"
  assert_success
  # shellcheck disable=SC2154
  run dd if=/dev/urandom of="$TEST_FILE_FOLDER/$bucket_file" bs=5M count=1
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run run_then_abort_multipart_upload "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER"/"$bucket_file" 4
  assert_success

  run object_exists "s3api" "$BUCKET_ONE_NAME" "$bucket_file"
  assert_failure 1
}

# complete-multipart-upload
@test "test_complete_multipart_upload" {
  local bucket_file="bucket-file"
  run create_test_files "$bucket_file"
  assert_success

  run dd if=/dev/urandom of="$TEST_FILE_FOLDER/$bucket_file" bs=5M count=1
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run multipart_upload "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER"/"$bucket_file" 4
  assert_success

  run download_and_compare_file "s3api" "$TEST_FILE_FOLDER/$bucket_file" "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER/$bucket_file-copy"
  assert_success
}

# create-multipart-upload
@test "test_create_multipart_upload_properties" {
  local bucket_file="bucket-file"

  local expected_content_type="application/zip"
  local expected_meta_key="testKey"
  local expected_meta_val="testValue"
  local expected_hold_status="ON"
  local expected_retention_mode="GOVERNANCE"
  local expected_tag_key="TestTag"
  local expected_tag_val="TestTagVal"

  os_name="$(uname)"
  if [[ "$os_name" == "Darwin" ]]; then
    now=$(date -u +"%Y-%m-%dT%H:%M:%S")
    later=$(date -j -v +15S -f "%Y-%m-%dT%H:%M:%S" "$now" +"%Y-%m-%dT%H:%M:%S")
  else
    now=$(date +"%Y-%m-%dT%H:%M:%S")
    later=$(date -d "$now 15 seconds" +"%Y-%m-%dT%H:%M:%S")
  fi

  run create_test_files "$bucket_file"
  assert_success

  run dd if=/dev/urandom of="$TEST_FILE_FOLDER/$bucket_file" bs=5M count=1
  assert_success

  run bucket_cleanup_if_bucket_exists "s3api" "$BUCKET_ONE_NAME"
  assert_success
  # in static bucket config, bucket will still exist
  if ! bucket_exists "s3api" "$BUCKET_ONE_NAME"; then
    run create_bucket_object_lock_enabled "$BUCKET_ONE_NAME"
    assert_success
  fi

  run multipart_upload_with_params "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER"/"$bucket_file" 4 \
    "$expected_content_type" \
    "{\"$expected_meta_key\": \"$expected_meta_val\"}" \
    "$expected_hold_status" \
    "$expected_retention_mode" \
    "$later" \
    "$expected_tag_key=$expected_tag_val"
  assert_success

  run get_and_verify_metadata "$bucket_file" "$expected_content_type" "$expected_meta_key" "$expected_meta_val" \
    "$expected_hold_status" "$expected_retention_mode" "$later"
  assert_success

  run check_verify_object_tags "s3api" "$BUCKET_ONE_NAME" "$bucket_file" "$expected_tag_key" "$expected_tag_val"
  assert_success

  run put_object_legal_hold "$BUCKET_ONE_NAME" "$bucket_file" "OFF"
  assert_success

  run get_and_check_legal_hold "s3api" "$BUCKET_ONE_NAME" "$bucket_file" "OFF"
  assert_success

  run download_and_compare_file "s3api" "$TEST_FILE_FOLDER/$bucket_file" "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER/$bucket_file-copy"
  assert_success
}

@test "test-multipart-upload-from-bucket" {
  local bucket_file="bucket-file"

  run create_test_file "$bucket_file"
  assert_success

  run dd if=/dev/urandom of="$TEST_FILE_FOLDER/$bucket_file" bs=5M count=1
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run multipart_upload_from_bucket "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER"/"$bucket_file" 4
  assert_success

  run get_object "s3api" "$BUCKET_ONE_NAME" "$bucket_file-copy" "$TEST_FILE_FOLDER/$bucket_file-copy"
  assert_success

  run compare_files "$TEST_FILE_FOLDER"/$bucket_file-copy "$TEST_FILE_FOLDER"/$bucket_file
  assert_success
}

@test "test_multipart_upload_from_bucket_range_too_large" {
  local bucket_file="bucket-file"
  run create_large_file "$bucket_file"
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run multipart_upload_range_too_large "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER"/"$bucket_file"
  assert_success
}

@test "test_multipart_upload_from_bucket_range_valid" {
  local bucket_file="bucket-file"
  run create_large_file "$bucket_file"
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run run_and_verify_multipart_upload_with_valid_range "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER/$bucket_file"
  assert_success
}

# test multi-part upload list parts command
@test "test-multipart-upload-list-parts" {
  local bucket_file="bucket-file"

  run create_test_file "$bucket_file" 0
  assert_success
  run dd if=/dev/urandom of="$TEST_FILE_FOLDER/$bucket_file" bs=5M count=1
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run start_multipart_upload_list_check_parts "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER"/"$bucket_file"
  assert_success

  run run_then_abort_multipart_upload "$BUCKET_ONE_NAME" "$bucket_file" "$TEST_FILE_FOLDER/$bucket_file" 4
  assert_success
}

# test listing of active uploads
@test "test-multipart-upload-list-uploads" {
  local bucket_file_one="bucket-file-one"
  local bucket_file_two="bucket-file-two"

  if [[ $RECREATE_BUCKETS == false ]]; then
    run abort_all_multipart_uploads "$BUCKET_ONE_NAME"
    assert_success
  fi

  run create_test_files "$bucket_file_one" "$bucket_file_two"
  assert_success

  run setup_bucket "s3api" "$BUCKET_ONE_NAME"
  assert_success

  run create_list_check_multipart_uploads "$BUCKET_ONE_NAME" "$bucket_file_one" "$bucket_file_two"
  assert_success
}
