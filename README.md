## README.md

# Customer Segmentation and Retention Strategy for TravelTide (Fictional Startup) ✈️

This project applies a SQL-based segmentation approach to analyze customer behavior for **TravelTide**, a **fictional e-booking startup**, on behalf of Elena Tarrant, the newly appointed Head of Marketing. The analysis identifies distinct traveler segments, evaluates their booking and engagement patterns, and recommends targeted perks for a rewards program. The results translate behavioral data into actionable marketing strategies that strengthen customer retention and drive value.


## 📊 Project Summary

The analysis covers about 5 million sessions and focuses on 5,782 active users (≥7 sessions between January and July 2023). Eight customer segments were identified through feature engineering, scoring rules, and prioritization logic, each with tailored perks to improve engagement and retention.

### 💡 Key Insights

- **Business Travellers** and **Families** are the high-value core and should be secured with dedicated perks.
- **Window Shoppers** and **Fresh Explorers** are untapped potential segments that can be activated through onboarding incentives and wishlist features.
- **Frequent Flyers** are loyal but under-monetized; cross-sell offers and bundles can unlock value.
- **Young Explorers** and **Bargain Seekers** are conversion-sensitive and respond strongly to discounts and last-minute deals.

Supporting materials include an executive summary slide deck, a detailed report, the segmentation SQL script, and optional visualizations (Tableau Public or Google Sheets).

## 🗄️ Database Connection

You can connect to the PostgreSQL database using:  
`postgres://Test:bQNxVzJL4g6u@ep-noisy-flower-846766.us-east-2.aws.neon.tech/TravelTide?sslmode=require`

---

## ⚙️ Installation

No installation required. The analysis can be run directly on the PostgreSQL database with the provided schema.

---

## ▶️ Usage

1. Clone the repository
2. Ensure your PostgreSQL database includes the required tables (`sessions`, `users`, `flights`, `hotels`)
3. Run `customer_segmentation.sql`
4. Review the segment summary with user distribution, booking rates, and recommended actions

---

## 🗂️ Directory Structure

- [README.md](README.md): Project documentation  
- [customer_segmentation.sql](customer_segmentation.sql): Segmentation logic  
- [detailed_report.pdf](detailed_report.pdf): Full report with findings and recommendations  
- [executive_summary.pdf](executive_summary.pdf): High-level summary of insights  
- [presentation_slides.pptx](presentation_slides.pptx): Slide deck for presentation  
- [sample_output_final.csv](sample_output_final.csv): Example of final segment-level output incl. average metrics and recommended perks  
- [schema.md](schema.md): Reference schema

---

## 🔧 Dependencies

- PostgreSQL (tested with version 13+)
- SQL client or IDE (DBeaver, pgAdmin, DataGrip)
- No additional dependencies required

---

## 📝 Example SQL Logic (Excerpt)

```sql
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
    END AS segment
FROM segment_scores;
```
---

## 🔍 Segment Features (High-Level)

- **Business Traveller**: short sessions, high weekday travel share
- **Family**: multiple seats, extra baggage, children present
- **Bargain Seeker**: long browsing, high engagement, discount usage
- **Young Explorer**: under 30, short stays, low spend
- **Frequent Flyer**: top 10% in flight bookings
- **Window Shopper**: browsing without bookings
- **Fresh Explorer**: new customer, early booking activity
- **Leisure Explorer**: fallback group when no strong signals apply

---

## 📜 License

MIT License – free to use and modify.

---

## 🔖 Tags

#SQL #CustomerSegmentation #MarketingAnalytics #BusinessIntelligence #PostgreSQL #TravelIndustry #TravelTide #BI
