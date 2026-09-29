package com.kiot.canteen.service;

import com.kiot.canteen.dto.AuthResponse;
import com.kiot.canteen.dto.UserDto;
import com.kiot.canteen.entity.User;
import com.kiot.canteen.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final SessionService sessions;

    public AuthService(UserRepository users, PasswordEncoder encoder, SessionService sessions) {
        this.users = users;
        this.encoder = encoder;
        this.sessions = sessions;
    }

    public AuthResponse login(String email, String password) {
        User user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password"));

        if (!encoder.matches(password, user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password");
        }

        String token = sessions.create(user.getId());
        return new AuthResponse(token, toDto(user));
    }

    public User require(Long id) {
        return users.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Session user not found"));
    }

    public static UserDto toDto(User u) {
        return new UserDto(u.getId(), u.getName(), u.getEmail(), u.getStudentId(), u.getRole());
    }
}
