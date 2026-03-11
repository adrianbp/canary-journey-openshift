FROM quay.io/openshift/origin-cli:4.15

USER 0
RUN microdnf install -y jq bash coreutils && microdnf clean all

WORKDIR /app

COPY infra/openshift/canaryrollout/controller/controller.sh /app/controller.sh
COPY infra/openshift/route-automation /app/route-automation

RUN chmod +x /app/controller.sh /app/route-automation/*.sh

ENV ROUTE_AUTOMATION_DIR=/app/route-automation \
    POLL_INTERVAL_SECONDS=15 \
    DEFAULT_MIN_CANARY_REPLICAS=1 \
    DEFAULT_PROMOTE_CANARY_BASELINE_REPLICAS=0 \
    DEFAULT_DISABLE_DELETE_PRIMARY=true \
    DEFAULT_DISABLE_SHIFT_STEP=25 \
    DEFAULT_DISABLE_WAIT_SECONDS=20 \
    EVENTS_ENABLED=true \
    MAX_STATUS_MESSAGE_LEN=700

ENTRYPOINT ["/app/controller.sh"]
