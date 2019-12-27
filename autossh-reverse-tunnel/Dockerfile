ARG BUILD_FROM
FROM $BUILD_FROM

ARG BUILD_ARCH

ENV LANG C.UTF-8

# Install alpine dependencies
RUN apk add --no-cache jq
RUN apk add --no-cache autossh

# Install yq for build architecture
RUN if [ "$BUILD_ARCH" = "armhf" ]; then wget -O yq https://github.com/mikefarah/yq/releases/download/2.1.2/yq_linux_arm ; fi
RUN if [ "$BUILD_ARCH" = "armv7" ]; then wget -O yq https://github.com/mikefarah/yq/releases/download/2.1.2/yq_linux_arm ; fi
RUN if [ "$BUILD_ARCH" = "aarch64" ]; then wget -O yq https://github.com/mikefarah/yq/releases/download/2.1.2/yq_linux_arm64 ; fi
RUN if [ "$BUILD_ARCH" = "amd64" ]; then wget -O yq https://github.com/mikefarah/yq/releases/download/2.1.2/yq_linux_amd64 ; fi
RUN if [ "$BUILD_ARCH" = "i386" ]; then wget -O yq https://github.com/mikefarah/yq/releases/download/2.1.2/yq_linux_386 ; fi

RUN chmod a+x ./yq

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
