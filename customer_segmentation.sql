/*
 Customer Segmentation & Retention Strategy for Travel Platform (TravelTide)
 Author: Roberto Pera
 Date: 2025/09/04
 Description: SQL pipeline to filter sessions, engineer features,
              score users, assign segments, and generate segment-level summary.
 Requirements: PostgreSQL 13+ with schema (sessions, users, flights, hotels)
 Input tables:
   - users: demographic info
   - sessions: browsing sessions
   - flights: flight bookings
   - hotels: hotel bookings
 Output:
   - segment_summary: summary of user segments with metrics and recommended actions
 Notes:
   - Uses haversine_distance() for travel distance calculation
   - Only users with >= 7 sessions are included
*/

/* ======================================================
   STEP 1: Filter sessions from 2023 onwards
====================================================== */
WITH sessions_2023 AS (
    SELECT *
    FROM sessions
    WHERE session_start >= '2023-01-05'
),

/* ======================================================
   STEP 2: Identify active users (>=7 sessions)
====================================================== */
active_users AS (
    SELECT
        user_id,
        COUNT(*) AS num_sessions
    FROM sessions_2023
    GROUP BY user_id
    HAVING COUNT(*) > 7
),

/* ======================================================
   STEP 3: Prepare session-level data with feature engineering
====================================================== */
session_level_prep AS (
    SELECT *,
        -- Clean negative nights values
        CASE
            WHEN nights < 0 THEN nights * -1
            ELSE DATE(check_out_time) - DATE(check_in_time)
        END AS nights_cleaned,

        -- Flag cancelled trips
        MAX(CASE WHEN cancellation = TRUE THEN 1 ELSE 0 END) OVER (PARTITION BY trip_id) AS trip_was_cancelled,

        -- Calculate session duration in minutes
        EXTRACT(EPOCH FROM (session_end - session_start)) / 60 AS minutes_in_session,

        -- Identify business trips (weekday trips within same week)
        CASE
            WHEN EXTRACT(ISODOW FROM departure_time) BETWEEN 1 AND 5
                AND EXTRACT(ISODOW FROM return_time) BETWEEN 1 AND 5
                AND DATE_TRUNC('week', departure_time) = DATE_TRUNC('week', return_time)
                AND (DATE(return_time) - DATE(departure_time)) <= 5
            THEN 1 ELSE 0
        END AS is_weekday_trip,

        -- Compute user age as of June 2023
        EXTRACT(YEAR FROM AGE('2023-06-01', birthdate)) AS age,

        -- Calculate travel distance for non-cancelled trips
        CASE
            WHEN cancellation = FALSE
            THEN haversine_distance(home_airport_lat, home_airport_lon,
                                  destination_airport_lat, destination_airport_lon)
        END AS travel_distance_km,

        -- Flight cost per person for non-cancelled bookings
        CASE
            WHEN cancellation = FALSE AND seats > 0
            THEN (base_fare_usd::DECIMAL * COALESCE((1 - flight_discount_amount), 1)) / seats
        END AS flight_cost_per_person,

        -- Identify combined flight + hotel bookings
        CASE
            WHEN cancellation = FALSE AND flight_booked AND hotel_booked
            THEN 1 ELSE 0
        END AS has_combined_booking

    FROM sessions_2023
    JOIN active_users USING(user_id)
    LEFT JOIN users USING(user_id)
    LEFT JOIN flights USING(trip_id)
    LEFT JOIN hotels USING(trip_id)
),

/* ======================================================
   STEP 4: Add hotel cost calculations
====================================================== */
session_level AS (
    SELECT *,
        -- Hotel cost calculation for non-cancelled bookings
        CASE
            WHEN cancellation = FALSE
            THEN hotel_per_room_usd::DECIMAL * rooms * nights_cleaned * COALESCE((1 - hotel_discount_amount), 1)
        END AS hotel_cost
    FROM session_level_prep
),

/* ======================================================
   STEP 5: Aggregate to user level - metrics per user
====================================================== */
user_level_aggregated AS (
    SELECT
        user_id,

        -- Browsing behavior metrics
        COUNT(session_id) AS total_sessions,
        SUM(page_clicks) AS total_page_clicks,
        SUM(minutes_in_session) AS total_session_minutes,

        -- Booking behavior metrics
        COUNT(DISTINCT trip_id) AS total_bookings,
        COUNT(DISTINCT CASE WHEN trip_was_cancelled = 0 THEN trip_id END) AS successful_bookings,
        SUM(CASE WHEN flight_booked AND cancellation = FALSE THEN 1 ELSE 0 END) AS flight_bookings,
        SUM(CASE WHEN hotel_booked AND cancellation = FALSE THEN 1 ELSE 0 END) AS hotel_bookings,
        SUM(seats) AS total_seats,
        SUM(checked_bags) AS total_bags,
        SUM(rooms) AS total_rooms,
        SUM(nights_cleaned) AS total_nights,
        COUNT(DISTINCT CASE WHEN is_weekday_trip = 1 THEN trip_id END) AS weekday_trips,
        SUM(travel_distance_km) AS total_travel_distance,
        COUNT(DISTINCT CASE WHEN hotel_discount OR flight_discount THEN trip_id END) AS discount_bookings,
        SUM(hotel_cost) AS total_hotel_cost,
        SUM(flight_cost_per_person) AS total_flight_cost,
        SUM(has_combined_booking) AS combined_bookings,

        -- User demographic info
        MAX(CASE WHEN married THEN 1 ELSE 0 END) AS is_married,
        MAX(CASE WHEN has_children THEN 1 ELSE 0 END) AS has_children,
        MAX(CASE WHEN trip_id IS NOT NULL AND trip_was_cancelled = 0
            THEN DATE(session_start) END) - MIN(DATE(sign_up_date)) AS days_since_signup_to_last_booking,
        MAX(age) AS age

    FROM session_level
    GROUP BY user_id
),

/* ======================================================
   STEP 6: Compute user-level features
====================================================== */
user_level_features AS (
    SELECT
        user_id,
        age,
        has_children,
        is_married,
        total_nights,

        -- Customer lifecycle indicators
        CASE WHEN age BETWEEN 20 AND 67 THEN 1 ELSE 0 END AS is_working_age,
        CASE WHEN days_since_signup_to_last_booking <= 28 THEN 1 ELSE 0 END AS is_new_customer,

        -- Browsing engagement metrics
        total_sessions,
        COALESCE(total_page_clicks::DECIMAL / NULLIF(total_sessions, 0), 0) AS avg_page_clicks_per_session,
        COALESCE(total_session_minutes::DECIMAL / NULLIF(total_sessions, 0), 0) AS avg_session_duration,

        -- Travel behavior metrics
        COALESCE(total_bookings::DECIMAL / NULLIF(total_sessions, 0), 0) AS booking_rate,
        COALESCE(total_seats::DECIMAL / NULLIF(flight_bookings, 0), 0) AS avg_seats_per_flight,
        COALESCE(total_bags::DECIMAL / NULLIF(flight_bookings, 0), 0) AS avg_bags_per_flight,
        COALESCE(weekday_trips::DECIMAL / NULLIF(total_bookings, 0), 0) AS weekday_travel_rate,
        COALESCE(successful_bookings::DECIMAL / NULLIF(total_bookings, 0), 0) AS booking_success_rate,
        COALESCE(discount_bookings::DECIMAL / NULLIF(total_bookings, 0), 0) AS discount_usage_rate,
        COALESCE(total_hotel_cost::DECIMAL / NULLIF(total_bookings, 0), 0) AS avg_hotel_cost_per_trip,
        COALESCE(total_flight_cost::DECIMAL / NULLIF(total_bookings, 0), 0) AS avg_flight_cost_per_trip,

        -- High-activity indicators
        CASE
            WHEN flight_bookings > (SELECT PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY flight_bookings)
                                   FROM user_level_aggregated)
            THEN 1 ELSE 0
        END AS is_frequent_flyer

    FROM user_level_aggregated
),

/* ======================================================
   STEP 7: Normalize key features for scoring
====================================================== */
normalized_features AS (
    SELECT
        user_id,
        age,
        is_frequent_flyer,
        total_nights,
        discount_usage_rate,
        weekday_travel_rate,
        booking_rate,
        is_new_customer,
        is_working_age,
        has_children,
        is_married,

        -- Non-booker indicator
        CASE WHEN booking_rate = 0 THEN 1 ELSE 0 END AS is_non_booker,

        -- Normalized travel behavior features
        (avg_bags_per_flight - MIN(avg_bags_per_flight) OVER()) /
            NULLIF((MAX(avg_bags_per_flight) OVER() - MIN(avg_bags_per_flight) OVER()), 0) AS bags_per_flight_norm,
        (avg_seats_per_flight - MIN(avg_seats_per_flight) OVER()) /
            NULLIF((MAX(avg_seats_per_flight) OVER() - MIN(avg_seats_per_flight) OVER()), 0) AS seats_per_flight_norm,
        (avg_flight_cost_per_trip - MIN(avg_flight_cost_per_trip) OVER()) /
            NULLIF((MAX(avg_flight_cost_per_trip) OVER() - MIN(avg_flight_cost_per_trip) OVER()), 0) AS flight_cost_norm,
        (avg_hotel_cost_per_trip - MIN(avg_hotel_cost_per_trip) OVER()) /
            NULLIF((MAX(avg_hotel_cost_per_trip) OVER() - MIN(avg_hotel_cost_per_trip) OVER()), 0) AS hotel_cost_norm,

        -- Engagement indicators
        CASE
            WHEN avg_page_clicks_per_session > (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY avg_page_clicks_per_session)
                                               FROM user_level_features) THEN 1 ELSE 0
        END AS is_high_engagement,
        CASE
            WHEN avg_session_duration > (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY avg_session_duration)
                                         FROM user_level_features) THEN 1 ELSE 0
        END AS is_long_session_user,
        CASE
            WHEN avg_session_duration < (SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY avg_session_duration)
                                         FROM user_level_features) THEN 1 ELSE 0
        END AS is_short_session_user,
        CASE
            WHEN total_nights > (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY total_nights)
                                FROM user_level_aggregated) THEN 1 ELSE 0
        END AS is_long_stay_traveler,
        CASE
            WHEN total_nights < (SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY total_nights)
                                FROM user_level_aggregated) THEN 1 ELSE 0
        END AS is_short_stay_traveler

    FROM user_level_features
),

/* ======================================================
   STEP 8: Calculate segment scores
====================================================== */
segment_scores AS (
    SELECT *,
        -- Business traveller score
        is_short_session_user * 0.15 +
        (1 - COALESCE(bags_per_flight_norm, 0)) * 0.2 +
        (1 - COALESCE(seats_per_flight_norm, 0)) * 0.2 +
        weekday_travel_rate * 0.45 AS business_score,

        -- Family score
        COALESCE(seats_per_flight_norm, 0) * 0.25 +
        has_children * 0.45 +
        COALESCE(bags_per_flight_norm, 0) * 0.25 +
        is_married * 0.05 AS family_score,

        -- Luxury score
        COALESCE(flight_cost_norm, 0) * 0.6 +
        COALESCE(hotel_cost_norm, 0) * 0.4 AS luxury_score,

        -- Deal hunter score
        is_long_session_user * 0.2 +
        is_high_engagement * 0.1 +
        discount_usage_rate * 0.7 AS deal_hunter_score,

        -- Young explorer score
        CASE WHEN age < 30 THEN 0.3 ELSE 0 END +
        is_short_stay_traveler * 0.3 +
        (1 - COALESCE(hotel_cost_norm, 0)) * 0.2 +
        (1 - COALESCE(flight_cost_norm, 0)) * 0.2 AS young_explorer_score

    FROM normalized_features
),

/* ======================================================
   STEP 9: Assign final user segments
====================================================== */
final_segments AS (
    SELECT
        user_id,
        CASE
            WHEN is_non_booker = 1 THEN 'Window Shopper'
            WHEN is_frequent_flyer = 1 THEN 'Frequent Flyer'
            WHEN is_new_customer = 1 THEN 'Fresh Explorer'
            WHEN young_explorer_score > 0.5 THEN 'Young Escaper'
            WHEN family_score >= GREATEST(deal_hunter_score, business_score) THEN 'Family'
            WHEN deal_hunter_score >= business_score THEN 'Bargain Seeker'
            WHEN business_score >= 0.4 THEN 'Business Traveller'
            ELSE 'Leisure Explorer'
        END AS segment,
        business_score,
        family_score,
        luxury_score,
        deal_hunter_score,
        young_explorer_score
    FROM segment_scores
),

/* ======================================================
   STEP 10: Generate segment-level summary
====================================================== */
segment_summary AS (
    SELECT
        fs.segment,
        COUNT(*) AS user_count,
        AVG(ulf.avg_flight_cost_per_trip) AS avg_flight_cost,
        AVG(ulf.avg_hotel_cost_per_trip) AS avg_hotel_cost,
        AVG(ulf.discount_usage_rate) AS avg_discount_rate,
        AVG(ulf.booking_success_rate) AS avg_success_rate,
        AVG(ulf.weekday_travel_rate) AS avg_weekday_rate,
        AVG(ulf.booking_rate) AS avg_booking_rate,

        -- Recommended actions for each segment
        CASE
            WHEN fs.segment = 'Window Shopper' THEN 'Wishlist feature with price alerts'
            WHEN fs.segment = 'Frequent Flyer' THEN 'Loyalty program'
            WHEN fs.segment = 'Fresh Explorer' THEN 'Welcome voucher'
            WHEN fs.segment = 'Young Escaper' THEN 'Last-minute deal offers'
            WHEN fs.segment = 'Family' THEN 'Extra baggage allowance'
            WHEN fs.segment = 'Bargain Seeker' THEN 'Personalized discount alerts'
            WHEN fs.segment = 'Business Traveller' THEN 'Priority boarding'
            WHEN fs.segment = 'Leisure Explorer' THEN 'Seasonal promotions'
        END AS recommended_action

    FROM final_segments fs
    JOIN user_level_features ulf USING(user_id)
    GROUP BY fs.segment
)

/* ======================================================
   STEP 11: Output final segment summary
====================================================== */
SELECT *
FROM segment_summary
ORDER BY user_count DESC;
