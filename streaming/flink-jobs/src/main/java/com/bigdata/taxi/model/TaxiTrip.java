package com.bigdata.taxi.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Model class for NYC Taxi Trip
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class TaxiTrip implements Serializable {
    private static final long serialVersionUID = 1L;
    private static final DateTimeFormatter formatter = DateTimeFormatter.ISO_DATE_TIME;

    @JsonProperty("tpep_pickup_datetime")
    @JsonAlias({"pickup_datetime"})
    private String pickupDatetime;

    @JsonProperty("tpep_dropoff_datetime")
    @JsonAlias({"dropoff_datetime"})
    private String dropoffDatetime;

    @JsonProperty("passenger_count")
    private Integer passengerCount;

    @JsonProperty("trip_distance")
    private Double tripDistance;

    @JsonProperty("pickup_longitude")
    private Double pickupLongitude;

    @JsonProperty("pickup_latitude")
    private Double pickupLatitude;

    @JsonProperty("dropoff_longitude")
    private Double dropoffLongitude;

    @JsonProperty("dropoff_latitude")
    private Double dropoffLatitude;

    @JsonProperty("payment_type")
    private Object paymentType;  // Can be Integer (1, 2) or String ("Credit", "Cash")

    @JsonProperty("fare_amount")
    private Double fareAmount;

    @JsonProperty("total_amount")
    private Double totalAmount;

    @JsonProperty("tip_amount")
    private Double tipAmount;

    @JsonProperty("pickup_zone")
    private String pickupZone;

    @JsonProperty("dropoff_zone")
    private String dropoffZone;

    @JsonProperty("duration_minutes")
    private Double durationMinutes;

    @JsonProperty("producer_timestamp")
    private String producerTimestamp;

    // Default constructor
    public TaxiTrip() {}

    // Getters and Setters
    public String getPickupDatetime() {
        return pickupDatetime;
    }

    public void setPickupDatetime(String pickupDatetime) {
        this.pickupDatetime = pickupDatetime;
    }

    public LocalDateTime getPickupDatetimeAsLocalDateTime() {
        if (pickupDatetime != null) {
            return LocalDateTime.parse(pickupDatetime, formatter);
        }
        return null;
    }

    public String getDropoffDatetime() {
        return dropoffDatetime;
    }

    public void setDropoffDatetime(String dropoffDatetime) {
        this.dropoffDatetime = dropoffDatetime;
    }

    public Integer getPassengerCount() {
        return passengerCount != null ? passengerCount : 0;
    }

    public void setPassengerCount(Integer passengerCount) {
        this.passengerCount = passengerCount;
    }

    public Double getTripDistance() {
        return tripDistance != null ? tripDistance : 0.0;
    }

    public void setTripDistance(Double tripDistance) {
        this.tripDistance = tripDistance;
    }

    public Double getPickupLongitude() {
        return pickupLongitude;
    }

    public void setPickupLongitude(Double pickupLongitude) {
        this.pickupLongitude = pickupLongitude;
    }

    public Double getPickupLatitude() {
        return pickupLatitude;
    }

    public void setPickupLatitude(Double pickupLatitude) {
        this.pickupLatitude = pickupLatitude;
    }

    public Double getDropoffLongitude() {
        return dropoffLongitude;
    }

    public void setDropoffLongitude(Double dropoffLongitude) {
        this.dropoffLongitude = dropoffLongitude;
    }

    public Double getDropoffLatitude() {
        return dropoffLatitude;
    }

    public void setDropoffLatitude(Double dropoffLatitude) {
        this.dropoffLatitude = dropoffLatitude;
    }

    public Object getPaymentType() {
        return paymentType;
    }

    public void setPaymentType(Object paymentType) {
        this.paymentType = paymentType;
    }

    public boolean isCashPayment() {
        if (paymentType == null) return false;
        // Handle Integer format (2 = Cash)
        if (paymentType instanceof Integer) {
            return (Integer) paymentType == 2;
        }
        // Handle String format ("Cash")
        if (paymentType instanceof String) {
            return ((String) paymentType).equalsIgnoreCase("Cash");
        }
        return false;
    }

    public boolean isCreditPayment() {
        if (paymentType == null) return false;
        // Handle Integer format (1 = Credit)
        if (paymentType instanceof Integer) {
            return (Integer) paymentType == 1;
        }
        // Handle String format ("Credit")
        if (paymentType instanceof String) {
            return ((String) paymentType).equalsIgnoreCase("Credit");
        }
        return false;
    }

    public Double getFareAmount() {
        return fareAmount != null ? fareAmount : 0.0;
    }

    public void setFareAmount(Double fareAmount) {
        this.fareAmount = fareAmount;
    }

    public Double getTotalAmount() {
        return totalAmount != null ? totalAmount : 0.0;
    }

    public void setTotalAmount(Double totalAmount) {
        this.totalAmount = totalAmount;
    }

    public Double getTipAmount() {
        return tipAmount != null ? tipAmount : 0.0;
    }

    public void setTipAmount(Double tipAmount) {
        this.tipAmount = tipAmount;
    }

    public String getPickupZone() {
        return pickupZone;
    }

    public void setPickupZone(String pickupZone) {
        this.pickupZone = pickupZone;
    }

    public String getDropoffZone() {
        return dropoffZone;
    }

    public void setDropoffZone(String dropoffZone) {
        this.dropoffZone = dropoffZone;
    }

    public Double getDurationMinutes() {
        return durationMinutes;
    }

    public void setDurationMinutes(Double durationMinutes) {
        this.durationMinutes = durationMinutes;
    }

    public String getProducerTimestamp() {
        return producerTimestamp;
    }

    public void setProducerTimestamp(String producerTimestamp) {
        this.producerTimestamp = producerTimestamp;
    }

    @Override
    public String toString() {
        return "TaxiTrip{" +
                "pickupDatetime='" + pickupDatetime + '\'' +
                ", pickupZone='" + pickupZone + '\'' +
                ", totalAmount=" + totalAmount +
                ", passengerCount=" + passengerCount +
                '}';
    }
}
