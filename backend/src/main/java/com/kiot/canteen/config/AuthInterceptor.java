package com.kiot.canteen.config;

import com.kiot.canteen.service.SessionService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class AuthInterceptor implements HandlerInterceptor {

    private final SessionService sessions;

    public AuthInterceptor(SessionService sessions) {
        this.sessions = sessions;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String token = request.getHeader(SessionService.HEADER);
        Long userId = sessions.resolve(token);
        if (userId != null) {
            request.setAttribute(SessionService.ATTR_USER_ID, userId);
        }
        return true;
    }
}
