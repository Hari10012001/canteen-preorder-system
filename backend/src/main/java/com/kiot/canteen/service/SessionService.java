package com.kiot.canteen.service;

import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory session store: token -> userId.
 * Prototype-grade replacement for JWT (listed as a future enhancement).
 */
@Service
public class SessionService {

    public static final String HEADER = "X-Auth-Token";
    public static final String ATTR_USER_ID = "kiotUserId";

    private final Map<String, Long> sessions = new ConcurrentHashMap<>();

    public String create(Long userId) {
        String token = UUID.randomUUID().toString();
        sessions.put(token, userId);
        return token;
    }

    public Long resolve(String token) {
        if (token == null || token.isBlank()) {
            return null;
        }
        return sessions.get(token);
    }

    public void invalidate(String token) {
        if (token != null) {
            sessions.remove(token);
        }
    }
}
