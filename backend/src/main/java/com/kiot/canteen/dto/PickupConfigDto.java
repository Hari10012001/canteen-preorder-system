package com.kiot.canteen.dto;

import java.time.LocalDate;
import java.util.List;

/** Pickup configuration returned to the frontend. */
public record PickupConfigDto(
        List<String> slots,
        int maxAdvanceDays
) {
}
