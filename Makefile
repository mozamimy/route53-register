DOCKER_IMAGE_NAME := route53-register-build

init:
	docker build -t ${DOCKER_IMAGE_NAME} .

build:
	docker run --rm -v ${PWD}:/workspace:cached -v ${PWD}/tmp/cargo-registry:/usr/local/cargo/registry:cached ${DOCKER_IMAGE_NAME} tools/build.sh

release_build:
	docker run --rm -v ${PWD}:/workspace:cached -v ${PWD}/tmp/cargo-registry:/usr/local/cargo/registry:cached -e RELEASE=1 ${DOCKER_IMAGE_NAME} tools/build.sh

run:
	jsonnet template.jsonnet --ext-str codeUri=${PWD}/target/debug/bootstrap.zip > template.dev.json
	echo '{"hello": "foo"}' | sam local invoke --template template.dev.json MainFunction

test:
	docker run --rm -v ${PWD}:/workspace:cached -v ${PWD}/tmp/cargo-registry:/usr/local/cargo/registry:cached ${DOCKER_IMAGE_NAME} cargo test

clean:
	cargo clean
	rm -rf tmp/cargo-registry/ *.json *.yaml
