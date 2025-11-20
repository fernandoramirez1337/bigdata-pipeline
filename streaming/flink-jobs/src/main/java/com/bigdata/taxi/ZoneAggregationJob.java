package com.bigdata.taxi;

import com.bigdata.taxi.model.TaxiTrip;
import com.bigdata.taxi.model.ZoneMetrics;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.AggregateFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.jdbc.JdbcConnectionOptions;
import org.apache.flink.connector.jdbc.JdbcExecutionOptions;
import org.apache.flink.connector.jdbc.JdbcSink;
import org.apache.flink.connector.jdbc.JdbcStatementBuilder;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.windowing.ProcessWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;

import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Duration;

/**
 * Flink Streaming Job: Zone-based Aggregation
 *
 * Consumes taxi trips from Kafka and aggregates metrics per zone
 * every 1 minute, writing results to PostgreSQL
 */
public class ZoneAggregationJob {

    private static final String KAFKA_BROKERS = "MASTER_IP:9092";  // UPDATE THIS
    private static final String KAFKA_TOPIC = "taxi-trips-stream";
    private static final String JDBC_URL = "jdbc:postgresql://STORAGE_IP:5432/bigdata_taxi";  // UPDATE THIS
    private static final String JDBC_USER = "bigdata";
    private static final String JDBC_PASSWORD = "bigdata123";

    public static void main(String[] args) throws Exception {
        // Set up the streaming execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Configure parallelism
        env.setParallelism(3);

        // Configure checkpointing
        env.enableCheckpointing(60000); // checkpoint every 60 seconds

        // Create Kafka source
        KafkaSource<String> kafkaSource = KafkaSource.<String>builder()
                .setBootstrapServers(KAFKA_BROKERS)
                .setTopics(KAFKA_TOPIC)
                .setGroupId("flink-zone-aggregation")
                .setStartingOffsets(OffsetsInitializer.latest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        // Read from Kafka
        DataStream<String> kafkaStream = env.fromSource(
                kafkaSource,
                WatermarkStrategy.forBoundedOutOfOrderness(Duration.ofSeconds(10)),
                "Kafka Source"
        );

        // Parse JSON to TaxiTrip objects
        DataStream<TaxiTrip> trips = kafkaStream
                .map(json -> {
                    ObjectMapper mapper = JsonMapper.builder()
                            .addModule(new JavaTimeModule())
                            .build();
                    return mapper.readValue(json, TaxiTrip.class);
                })
                .filter(trip -> trip.getPickupZone() != null && !trip.getPickupZone().isEmpty())
                .name("Parse and Filter");

        // Aggregate by zone every 1 minute
        DataStream<ZoneMetrics> zoneMetrics = trips
                .keyBy(TaxiTrip::getPickupZone)
                .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
                .aggregate(
                        new ZoneAggregator(),
                        new ZoneMetricsProcessor()
                )
                .name("Zone Aggregation");

        // Sink to PostgreSQL
        zoneMetrics.addSink(
                JdbcSink.sink(
                        "INSERT INTO real_time_zones " +
                        "(zone_id, window_start, window_end, trip_count, total_revenue, " +
                        "avg_fare, avg_distance, avg_passengers, payment_cash_count, payment_credit_count) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) " +
                        "ON CONFLICT (zone_id, window_start) DO UPDATE SET " +
                        "trip_count = EXCLUDED.trip_count, " +
                        "total_revenue = EXCLUDED.total_revenue, " +
                        "avg_fare = EXCLUDED.avg_fare, " +
                        "avg_distance = EXCLUDED.avg_distance, " +
                        "avg_passengers = EXCLUDED.avg_passengers, " +
                        "payment_cash_count = EXCLUDED.payment_cash_count, " +
                        "payment_credit_count = EXCLUDED.payment_credit_count",
                        (JdbcStatementBuilder<ZoneMetrics>) (ps, metrics) -> {
                            ps.setString(1, metrics.getZoneId());
                            ps.setTimestamp(2, metrics.getWindowStart());
                            ps.setTimestamp(3, metrics.getWindowEnd());
                            ps.setLong(4, metrics.getTripCount());
                            ps.setDouble(5, metrics.getTotalRevenue());
                            ps.setDouble(6, metrics.getAvgFare());
                            ps.setDouble(7, metrics.getAvgDistance());
                            ps.setDouble(8, metrics.getAvgPassengers());
                            ps.setLong(9, metrics.getPaymentCashCount());
                            ps.setLong(10, metrics.getPaymentCreditCount());
                        },
                        JdbcExecutionOptions.builder()
                                .withBatchSize(100)
                                .withBatchIntervalMs(5000)
                                .withMaxRetries(3)
                                .build(),
                        new JdbcConnectionOptions.JdbcConnectionOptionsBuilder()
                                .withUrl(JDBC_URL)
                                .withDriverName("org.postgresql.Driver")
                                .withUsername(JDBC_USER)
                                .withPassword(JDBC_PASSWORD)
                                .build()
                )
        ).name("PostgreSQL Sink");

        // Execute program
        env.execute("NYC Taxi Zone Aggregation Job");
    }

    /**
     * Aggregate function to accumulate trip statistics
     */
    public static class ZoneAggregator implements AggregateFunction<TaxiTrip, ZoneAccumulator, ZoneAccumulator> {

        @Override
        public ZoneAccumulator createAccumulator() {
            return new ZoneAccumulator();
        }

        @Override
        public ZoneAccumulator add(TaxiTrip trip, ZoneAccumulator acc) {
            acc.count++;
            acc.totalRevenue += trip.getTotalAmount();
            acc.totalFare += trip.getFareAmount();
            acc.totalDistance += trip.getTripDistance();
            acc.totalPassengers += trip.getPassengerCount();

            if (trip.isCashPayment()) {
                acc.cashPayments++;
            } else if (trip.isCreditPayment()) {
                acc.creditPayments++;
            }

            return acc;
        }

        @Override
        public ZoneAccumulator getResult(ZoneAccumulator acc) {
            return acc;
        }

        @Override
        public ZoneAccumulator merge(ZoneAccumulator a, ZoneAccumulator b) {
            a.count += b.count;
            a.totalRevenue += b.totalRevenue;
            a.totalFare += b.totalFare;
            a.totalDistance += b.totalDistance;
            a.totalPassengers += b.totalPassengers;
            a.cashPayments += b.cashPayments;
            a.creditPayments += b.creditPayments;
            return a;
        }
    }

    /**
     * Process window function to create ZoneMetrics from accumulator
     */
    public static class ZoneMetricsProcessor
            extends ProcessWindowFunction<ZoneAccumulator, ZoneMetrics, String, TimeWindow> {

        @Override
        public void process(String zoneId,
                          Context context,
                          Iterable<ZoneAccumulator> elements,
                          Collector<ZoneMetrics> out) {

            ZoneAccumulator acc = elements.iterator().next();

            ZoneMetrics metrics = new ZoneMetrics();
            metrics.setZoneId(zoneId);
            metrics.setWindowStart(new Timestamp(context.window().getStart()));
            metrics.setWindowEnd(new Timestamp(context.window().getEnd()));
            metrics.setTripCount(acc.count);
            metrics.setTotalRevenue(acc.totalRevenue);
            metrics.setAvgFare(acc.count > 0 ? acc.totalFare / acc.count : 0.0);
            metrics.setAvgDistance(acc.count > 0 ? acc.totalDistance / acc.count : 0.0);
            metrics.setAvgPassengers(acc.count > 0 ? (double) acc.totalPassengers / acc.count : 0.0);
            metrics.setPaymentCashCount(acc.cashPayments);
            metrics.setPaymentCreditCount(acc.creditPayments);

            out.collect(metrics);
        }
    }

    /**
     * Accumulator for zone statistics
     */
    public static class ZoneAccumulator {
        public long count = 0;
        public double totalRevenue = 0.0;
        public double totalFare = 0.0;
        public double totalDistance = 0.0;
        public long totalPassengers = 0;
        public long cashPayments = 0;
        public long creditPayments = 0;
    }
}
