package com.kiot.canteen.service;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import com.kiot.canteen.entity.Order;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.EnumMap;
import java.util.Map;

@Service
public class QrService {

    private static final int SIZE = 420;

    public byte[] toPng(Order order) {
        String content = buildContent(order);

        Map<EncodeHintType, Object> hints = new EnumMap<>(EncodeHintType.class);
        hints.put(EncodeHintType.CHARACTER_SET, StandardCharsets.UTF_8.name());
        hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M);
        hints.put(EncodeHintType.MARGIN, 1);

        try {
            BitMatrix matrix = new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, SIZE, SIZE, hints);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            MatrixToImageWriter.writeToStream(matrix, "PNG", out);
            return out.toByteArray();
        } catch (WriterException | java.io.IOException e) {
            throw new IllegalStateException("Failed to generate QR code", e);
        }
    }

    public String buildContent(Order order) {
        return """
                KIOT CANTEEN PRE-ORDER
                Order ID: %s
                Student: %s
                Student ID: %s
                Pickup: %s %s
                Order Status: %s
                Payment: %s (%s)
                Total: Rs. %s
                Items: %d
                """.formatted(
                order.getOrderCode(),
                order.getUser().getName(),
                order.getUser().getStudentId() == null ? "-" : order.getUser().getStudentId(),
                order.getPickupDate(),
                order.getPickupSlot(),
                order.getOrderStatus().name(),
                order.getPaymentMethod().name(),
                order.getPaymentStatus().name(),
                order.getTotalAmount().setScale(2),
                order.getItems().stream().mapToInt(i -> i.getQuantity()).sum());
    }
}
