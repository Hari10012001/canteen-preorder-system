package com.kiot.canteen.dto;

import java.time.LocalDate;
import java.util.List;

public record ApiError(String message, String path) {
}
