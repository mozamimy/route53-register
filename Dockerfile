FROM lambci/lambda:build-provided

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

ARG RUST_VERSION=1.35.0

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain $RUST_VERSION
RUN rustup component add rustfmt
RUN mkdir /workspace
WORKDIR /workspace

CMD ["rustup", "--version"]
