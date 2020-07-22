FROM devorbitus/docker-vault-jq:latest

RUN apt-get update && apt-get install -y build-essential curl

COPY dynamic-accounts.sh .

RUN ["chmod", "+x", "./dynamic-accounts.sh"]

ENTRYPOINT ["./dynamic-accounts.sh"]
