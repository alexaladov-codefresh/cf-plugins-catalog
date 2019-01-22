#!/bin/bash

set -e

RED='\033[0;31m' # Red
GREEN='\033[0;32m' # Green
NC='\033[0m' # No Color

part(){
       truncate -s 0 /tmp/result.json
       cat "$1$2" | yq --argjson pipeline "$(cat $1$3 | yq .)" \
       '{"id":"test","title":"test","source":.sources[1],"description":.description,"category":"test","handle":"test","create":"test","author":"test","view_count":"0","usage_sample":[{"content":$pipeline},{"variable":.envs}]}'> /tmp/result.json
       cat '/tmp/step.json' | jq -r --argjson pipeline "$(cat '/tmp/result.json' | jq .)" '. +=  [$pipeline]' > /tmp/step.json
      }

yaml_check(){
             if [ -f "$1$2" ]; then
                   yq . "$1$2" >/dev/null 2>/dev/null \
                   && echo -e "$1$2 <--YAML Syntax check ${GREEN}OK${NC}" \
                   || echo -e "$1$2 <--YAML Syntax check ${RED}FAILED${NC}" \
                   && flag=0
             else
                   echo -e "${RED}Please create file${NC} $1plugin.yaml"
                   flag=0
             fi
             if [ -f "$1$3" ]; then
                   yq . "$1$3" >/dev/null 2>/dev/null \
                   && echo -e "$1$3 <--YAML Syntax check ${GREEN}OK${NC}" \
                   || echo -e "$1$3 <--YAML Syntax check ${RED}FAILED${NC}" \
                   && flag=0
             else
                   echo -e "${RED}Please create file${NC} $1pipeline.yaml"
                   flag=0
             fi
             }


###########################################################
export BASE_DIR=$(pwd)
#clear steps file
truncate -s 0 /tmp/step.json
# new array in steps file
echo '[]' | jq '.' > /tmp/step.json


#Syntax check
echo -e "${GREEN}-----------------------"
echo -e "Syntax check started..."
echo -e "-----------------------${NC}"

for d in ${BASE_DIR}/plugins/*/; do
pipeline=$(basename $d/pipeline.y*)
plugin=$(basename $d/plugin.y*)
  yaml_check $d $plugin $pipeline
done

if [ flag==0 ]; then
echo -e "${RED}-----------------------------------------"
echo -e "Please correct found problems and restart"
echo -e "-----------------------------------------${NC}"
exit 1
fi


#making step.json file
for d in ${BASE_DIR}/plugins/*/; do
    echo "Processing Dir -> $d"
  pipeline=$(basename $d/pipeline.y*)
  #echo "$pipeline"
  plugin=$(basename $d/plugin.y*)
  #echo "$plugin"
    if [ -f "$d/$pipeline" ] && [ -f "$d/$plugin" ]; then
      part $d $plugin $pipeline
    fi
  pipeline=''
  plugin=''
done

cp /tmp/step.json ${BASE_DIR}/step.json
