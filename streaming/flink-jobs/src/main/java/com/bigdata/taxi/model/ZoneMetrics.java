package com.bigdata.taxi.model;

import java.io.Serializable;
import java.sql.Timestamp;

/**
 * Aggregated metrics per zone
 */
public class ZoneMetrics implements Serializable {
    private static final long serialVersionUID = 1L;

    private String zoneId;
    private Timestamp windowStart;
    private Timestamp windowEnd;
    private Long tripCount;
    private Double totalRevenue;
    private Double avgFare;
    private Double avgDistance;
    private Double avgPassengers;
    private Long paymentCashCount;
    private Long paymentCreditCount;

    public ZoneMetrics() {}

    public ZoneMetrics(String zoneId, Timestamp windowStart, Timestamp windowEnd) {
        this.zoneId = zoneId;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
        this.tripCount = 0L;
        this.totalRevenue = 0.0;
        this.avgFare = 0.0;
        this.avgDistance = 0.0;
        this.avgPassengers = 0.0;
        this.paymentCashCount = 0L;
        this.paymentCreditCount = 0L;
    }

    // Getters and Setters
    public String getZoneId() {
        return zoneId;
    }

    public void setZoneId(String zoneId) {
        this.zoneId = zoneId;
    }

    public Timestamp getWindowStart() {
        return windowStart;
    }

    public void setWindowStart(Timestamp windowStart) {
        this.windowStart = windowStart;
    }

    public Timestamp getWindowEnd() {
        return windowEnd;
    }

    public void setWindowEnd(Timestamp windowEnd) {
        this.windowEnd = windowEnd;
    }

    public Long getTripCount() {
        return tripCount;
    }

    public void setTripCount(Long tripCount) {
        this.tripCount = tripCount;
    }

    public Double getTotalRevenue() {
        return totalRevenue;
    }

    public void setTotalRevenue(Double totalRevenue) {
        this.totalRevenue = totalRevenue;
    }

    public Double getAvgFare() {
        return avgFare;
    }

    public void setAvgFare(Double avgFare) {
        this.avgFare = avgFare;
    }

    public Double getAvgDistance() {
        return avgDistance;
    }

    public void setAvgDistance(Double avgDistance) {
        this.avgDistance = avgDistance;
    }

    public Double getAvgPassengers() {
        return avgPassengers;
    }

    public void setAvgPassengers(Double avgPassengers) {
        this.avgPassengers = avgPassengers;
    }

    public Long getPaymentCashCount() {
        return paymentCashCount;
    }

    public void setPaymentCashCount(Long paymentCashCount) {
        this.paymentCashCount = paymentCashCount;
    }

    public Long getPaymentCreditCount() {
        return paymentCreditCount;
    }

    public void setPaymentCreditCount(Long paymentCreditCount) {
        this.paymentCreditCount = paymentCreditCount;
    }

    @Override
    public String toString() {
        return "ZoneMetrics{" +
                "zoneId='" + zoneId + '\'' +
                ", windowStart=" + windowStart +
                ", tripCount=" + tripCount +
                ", totalRevenue=" + totalRevenue +
                ", avgFare=" + avgFare +
                '}';
    }
}
