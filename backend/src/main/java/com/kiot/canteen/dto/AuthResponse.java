package com.kiot.canteen.dto;

public record AuthResponse(String token, UserDto user) {
}
