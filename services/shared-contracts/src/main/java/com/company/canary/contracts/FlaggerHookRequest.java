package com.company.canary.contracts;

import java.util.Map;

public record FlaggerHookRequest(
        String name,
        String namespace,
        String phase,
        String checksum,
        Map<String, String> metadata
) {
}
