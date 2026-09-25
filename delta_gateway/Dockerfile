ARG BUILD_FROM
FROM $BUILD_FROM

# curl + jq to talk to the Delta EnergyOS API, openssl to verify the ed25519
# signature on the supervisor binary before it is ever executed.
RUN apk add --no-cache curl jq openssl

COPY rootfs /
RUN chmod a+x /etc/s6-overlay/scripts/*.sh \
    /etc/s6-overlay/s6-rc.d/ems-supervisor/run \
    /etc/s6-overlay/s6-rc.d/ems-edge/run
