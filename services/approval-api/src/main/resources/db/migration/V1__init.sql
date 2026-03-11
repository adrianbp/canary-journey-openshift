CREATE TABLE approval_requests (
    id UUID PRIMARY KEY,
    cluster VARCHAR(100) NOT NULL,
    namespace VARCHAR(100) NOT NULL,
    canary_name VARCHAR(255) NOT NULL,
    revision VARCHAR(100) NOT NULL,
    step_type VARCHAR(64) NOT NULL,
    status VARCHAR(64) NOT NULL,
    requested_by VARCHAR(255) NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    decision_by VARCHAR(255),
    decision_reason TEXT,
    decided_at TIMESTAMPTZ,
    snow_task_id VARCHAR(255)
);

CREATE INDEX idx_approval_requests_lookup
ON approval_requests (cluster, namespace, canary_name, revision, step_type, requested_at DESC);

CREATE TABLE approval_events (
    id BIGSERIAL PRIMARY KEY,
    approval_id UUID NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    actor VARCHAR(255) NOT NULL,
    payload TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_approval_events_approval
        FOREIGN KEY (approval_id) REFERENCES approval_requests(id)
);

CREATE TABLE idempotency_keys (
    key VARCHAR(255) PRIMARY KEY,
    scope VARCHAR(120) NOT NULL,
    request_hash VARCHAR(255) NOT NULL,
    response_snapshot TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);
