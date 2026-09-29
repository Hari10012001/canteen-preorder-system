package com.kiot.canteen.dto;

/** Safe user projection - never exposes the password hash. */
public record UserDto(Long id, String name, String email, String studentId, String role) {
}
