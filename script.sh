#!/bin/bash

set -e

RED='\033[0;31m' # Red
GREEN='\033[0;32m' # Green
NC='\033[0m' # No Color

part(){
       truncate -s 0 /tmp/result.json
       cat "$1$2" | yq --argjson pipeline "$(cat $1$3 | yq .)" \
       --arg uuid "$( cat "$1$2" | yq -r  '.title' | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g')" \
       --arg created "$(date -d @"$(git log --format=%at $1$2 | tail -1)" +%FT%T.000Z)" \
       '{"id":$uuid,"title":.title,"source":.source,"description":.description,"category":.category,"handle":$uuid,"create":$created,"author":.maintainer[0].name,"view_count":"0","usage_sample":[{"content":$pipeline,"variable":.envs}]}'> /tmp/result.json
       cat '/tmp/step.json' | jq -r --argjson pipeline "$(cat '/tmp/result.json' | jq .)" '. +=  [$pipeline]' > /tmp/step.json
      }

logo_download(){
                LOGO_FILENAME="$(cat "$1$2" | yq -r  '.title' | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g')"
                LOGO_LINK="$(cat "$1$2" | yq -r  '.logo' )"
                STATUS="$(curl -s -o /dev/null -I -w "%{http_code}" ${LOGO_LINK})"
                if [ "$STATUS" == "200" ]; then
                  curl -s  "${LOGO_LINK}" --output "${BASE_DIR}/logos/${LOGO_FILENAME}.jpg"  # any image type needs to have a .jpg extension by the app design
                  echo -e "Logo for the plugin ${LOGO_FILENAME} ${GREEN}Downloaded${NC}"
                else
                   echo -e "Error accessing logo for the plugin ${LOGO_FILENAME} Error: ${RED}${STATUS}${NC}"
                   exit 1
                fi
                }

yaml_check(){
             if [ -f "$1$2" ]; then
                   if yq . "$1$2" >/dev/null 2>/dev/null; then
                      echo -e "$1$2 <--YAML Syntax check ${GREEN}OK${NC}"
                   else echo -e "$1$2 <--YAML Syntax check ${RED}FAILED${NC}"
                        result='fail'
                   fi
             else
                   echo -e "${RED}Please create file${NC} $1plugin.yaml"
                   result='fail'
             fi
             if [ -f "$1$3" ]; then
                   if yq . "$1$3" >/dev/null 2>/dev/null; then
                      echo -e "$1$3 <--YAML Syntax check ${GREEN}OK${NC}"
                   else echo -e "$1$3 <--YAML Syntax check ${RED}FAILED${NC}"
                        result='fail'
                   fi
             else
                   echo -e "${RED}Please create file${NC} $1example.yaml"
                   result='fail'
             fi
             }

replace_keys_with_ids(){
                        cat "$1" | jq '.' | \
                        jq --argjson arg "$( cat $2 | jq '[ .[] | {(.title) : (.id)} ] | add' )" \
                        '.[] | .category as $key | if $arg | has($key[0]) then  .category|=[$arg[$key[]]] else .category|=[$arg["Featured"]] end'| jq -s '.' > $1
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
pipeline=$(basename $d/example.y*)
plugin=$(basename $d/plugin.y*)
  yaml_check $d $plugin $pipeline
done


if [ "$result" == "fail" ]; then
echo -e "${RED}-----------------------------------------"
echo -e "Please correct found problems and restart"
echo -e "-----------------------------------------${NC}"
#exit 1
fi


#making step.json file and downloading logos
mkdir -p ${BASE_DIR}/logos/
for d in ${BASE_DIR}/plugins/*/; do
    echo "Processing Dir -> $d"
  pipeline=$(basename $d/example.y*)
  #echo "$pipeline"
  plugin=$(basename $d/plugin.y*)
  #echo "$plugin"
    if [ -f "$d/$pipeline" ] && [ -f "$d/$plugin" ] && [ -f "$d/README.md" ]; then
      part $d $plugin $pipeline
      logo_download $d $plugin
      echo -e "Plugin configuration ${GREEN}Created${NC}"
    fi
  pipeline=''
  plugin=''
done

#replace keys with ids
#cat /tmp/step.json
if [ -f $BASE_DIR/plugins/categories.yaml ]; then
cat $BASE_DIR/plugins/categories.yaml | yq '.' > $BASE_DIR/category.json
echo "Replacing categories with IDs"
replace_keys_with_ids /tmp/step.json $BASE_DIR/category.json
#copy step.json to a base dir
cp /tmp/step.json $BASE_DIR/step.json
#cat $BASE_DIR/step.json
echo -e "${GREEN}Done${NC}"
else
echo -e "categories.yaml file ${RED}not found${NC}"
echo -e "${RED}Place categories.yaml file into plugins directory and restart${NC}"
exit 1
fi
