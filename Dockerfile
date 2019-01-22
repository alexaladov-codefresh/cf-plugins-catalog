FROM alpine:3.8

RUN apk add \
    bash jq py-pip \
&&  pip install yq

COPY ./script.sh /script.sh
RUN chmod +x /script.sh

CMD ["/script.sh"] 
