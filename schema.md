## schema.md

# 📋 TravelTide Database Schema Reference

This file documents the database tables, columns, types, and a short description of each field. It is intended for reference and understanding the database structure.

| Table | Column | Type | Description |
|-------|--------|------|-------------|
| `users` | `user_id` | int | Unique user ID (primary key) |
|  | `birthdate` | datetime | User date of birth |
|  | `gender` | nominal | User gender |
|  | `married` | binary | User marriage status |
|  | `has_children` | binary | Whether the user has children |
|  | `home_country` | nominal | User’s resident country |
|  | `home_city` | nominal | User’s resident city |
|  | `home_airport` | nominal | User’s preferred home airport |
|  | `home_airport_lat` | decimal | Geographical north-south position of home airport |
|  | `home_airport_lon` | decimal | Geographical east-west position of home airport |
|  | `sign_up_date` | datetime | TravelTide account creation date |
| `sessions` | `session_id` | string | Unique browsing session ID |
|  | `user_id` | int | Foreign key to `users` |
|  | `trip_id` | string | Foreign key to trips (`flights`/`hotels`) |
|  | `session_start` | timestamp | Session start time |
|  | `session_end` | timestamp | Session end time |
|  | `flight_discount` | binary | Whether flight discount was offered |
|  | `hotel_discount` | binary | Whether hotel discount was offered |
|  | `flight_discount_amount` | decimal | Percentage off base fare |
|  | `hotel_discount_amount` | decimal | Percentage off base night rate |
|  | `flight_booked` | binary | Whether flight was booked |
|  | `hotel_booked` | binary | Whether hotel was booked |
|  | `page_clicks` | int | Number of page clicks |
|  | `cancellation` | binary | Whether session cancelled a trip |
| `flights` | `trip_id` | string | Unique trip ID (primary key) |
|  | `origin_airport` | nominal | User’s home airport |
|  | `destination` | nominal | Destination city |
|  | `destination_airport` | nominal | Airport in destination city |
|  | `seats` | int | Number of seats booked |
|  | `return_flight_booked` | binary | Whether return flight was booked |
|  | `departure_time` | timestamp | Departure time |
|  | `return_time` | timestamp | Return time |
|  | `checked_bags` | int | Number of checked bags |
|  | `trip_airline` | nominal | Airline for trip |
|  | `destination_airport_lat` | decimal | North-south position of destination airport |
|  | `destination_airport_lon` | decimal | East-west position of destination airport |
|  | `base_fare_usd` | decimal | Pre-discount price of airfare |
| `hotels` | `trip_id` | string | Unique trip ID (primary key) |
|  | `hotel_name` | nominal | Hotel brand name |
|  | `nights` | int | Number of nights stayed |
|  | `rooms` | int | Number of rooms booked |
|  | `check_in_time` | timestamp | Hotel check-in time |
|  | `check_out_time` | timestamp | Hotel check-out time |
|  | `hotel_per_room_usd` | decimal | Pre-discount price per room per night |
