package com.kiot.canteen.controller;

import com.kiot.canteen.config.CurrentUser;
import com.kiot.canteen.dto.AuthResponse;
import com.kiot.canteen.dto.LoginRequest;
import com.kiot.canteen.dto.UserDto;
import com.kiot.canteen.service.AuthService;
import com.kiot.canteen.service.SessionService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;
    private final SessionService sessions;

    public AuthController(AuthService auth, SessionService sessions) {
        this.auth = auth;
        this.sessions = sessions;
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return auth.login(request.email().trim(), request.password());
    }

    @PostMapping("/logout")
    public UserDto logout(HttpServletRequest request) {
        Long userId = CurrentUser.id(request);
        sessions.invalidate(request.getHeader(SessionService.HEADER));
        return auth.require(userId) == null ? null : AuthService.toDto(auth.require(userId));
    }

    @GetMapping("/me")
    public UserDto me(HttpServletRequest request) {
        return AuthService.toDto(auth.require(CurrentUser.id(request)));
    }
}
