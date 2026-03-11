package com.company.canary.contracts;

import com.fasterxml.jackson.annotation.JsonCreator;

public enum StepType {
    ROLLOUT,
    ROLLBACK,
    CONFIRM_PROMOTION,
    CONFIRM_ROLLOUT;

    @JsonCreator
    public static StepType fromValue(String value) {
        return StepType.valueOf(value.toUpperCase().replace('-', '_'));
    }
}
