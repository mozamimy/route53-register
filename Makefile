DOCKER_IMAGE_NAME := route53-register-build
CHANGE_SET_NAME := $(shell echo ${STACK_NAME}-`uuidgen`)

init:
	docker build -t ${DOCKER_IMAGE_NAME} .

build:
	docker run --rm -v ${PWD}:/workspace:cached -v ${PWD}/tmp/cargo-registry:/usr/local/cargo/registry:cached ${DOCKER_IMAGE_NAME} tools/build.sh

release-build:
	docker run --rm -v ${PWD}:/workspace:cached -v ${PWD}/tmp/cargo-registry:/usr/local/cargo/registry:cached -e RELEASE=1 ${DOCKER_IMAGE_NAME} tools/build.sh

run-create-record:
	jsonnet template.jsonnet \
		 --ext-str codeUri=${PWD}/target/debug/bootstrap.zip \
		 --ext-str dnsSuffix=${DNS_SUFFIX} \
		 --ext-str hostedZoneId=${HOSTED_ZONE_ID} \
		 --ext-str lambdaRole=${LAMBDA_ROLE} \
		 --ext-str dlqName=${DLQ_NAME} \
			> template.dev.json
	jsonnet examples/event-template.jsonnet \
		--ext-str instanceId=${TEST_INSTANCE_ID} \
		--ext-str state=running \
			> examples/running.json
	cat examples/running.json | sam local invoke --template template.dev.json MainFunction

run-delete-record:
	jsonnet template.jsonnet \
		 --ext-str codeUri=${PWD}/target/debug/bootstrap.zip \
		 --ext-str dnsSuffix=${DNS_SUFFIX} \
		 --ext-str hostedZoneId=${HOSTED_ZONE_ID} \
		 --ext-str lambdaRole=${LAMBDA_ROLE} \
		 --ext-str dlqName=${DLQ_NAME} \
			> template.dev.json
	jsonnet examples/event-template.jsonnet \
		--ext-str instanceId=${TEST_INSTANCE_ID} \
		--ext-str state=shutting-down \
			> examples/shutting-down.json
	cat examples/shutting-down.json | sam local invoke --template template.dev.json MainFunction

test:
	docker run --rm -v ${PWD}:/workspace:cached -v ${PWD}/tmp/cargo-registry:/usr/local/cargo/registry:cached ${DOCKER_IMAGE_NAME} cargo test

package:
	jsonnet template.jsonnet \
		 --ext-str codeUri=${PWD}/target/release/bootstrap.zip \
		 --ext-str dnsSuffix=${DNS_SUFFIX} \
		 --ext-str hostedZoneId=${HOSTED_ZONE_ID} \
		 --ext-str lambdaRole=${LAMBDA_ROLE} \
		 --ext-str dlqName=${DLQ_NAME} \
			> template.json
	sam validate --template template.json
	sam package --template-file template.json --output-template-file template.packaged.yaml --s3-bucket ${SAM_ARTIFACT_BUCKET} --s3-prefix ${STACK_NAME} --region ${AWS_REGION}

plan:
	aws cloudformation create-change-set --stack-name ${STACK_NAME} --template-body file://template.packaged.yaml --change-set-name ${CHANGE_SET_NAME} --region ${AWS_REGION}
	aws cloudformation wait change-set-create-complete --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --region ${AWS_REGION}
	aws cloudformation describe-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --region ${AWS_REGION} | jq
	aws cloudformation delete-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --region ${AWS_REGION}

deploy:
	sam deploy --template-file template.packaged.yaml --stack-name ${STACK_NAME} --capabilities CAPABILITY_IAM --region ${AWS_REGION}

clean:
	cargo clean
	rm -rf tmp/cargo-registry/ *.json *.yaml
