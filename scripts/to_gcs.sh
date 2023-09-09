#
# Copyright 2023 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
echo
echo "*****"
echo Exporting to GCS
echo "*****"
echo
if [[ -z $2 ]]; then
    echo "No GCS Output Bucket Specified"
else
    if [ -d "$1" ] && [ $(ls -A "$1" | wc -l) -ne 0 ]; then
        echo gsutil cp -R $1/* $2
        gsutil cp -R $1/* $2
    else
        echo "No output generated."
    fi
fi