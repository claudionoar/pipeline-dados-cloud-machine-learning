-- Tabela final para consumo pelo módulo de Machine Learning (machine-learning/data_prep.py):
-- uma linha por pedido entregue, com features estruturadas + o alvo is_late (atraso na entrega).
--
-- distance_km usa a função nativa HAVERSINE() do Snowflake entre o centróide de CEP do cliente
-- e do vendedor "primário" do pedido (o do primeiro item - simplificação documentada: pedidos
-- com vários vendedores/itens usam só a localização do primeiro item).

with orders as (
    select * from PROJETO_OLIST_DB.ANALYTICS.fact_orders
),

customers as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_customers
),

items as (
    select * from PROJETO_OLIST_DB.ANALYTICS.fact_order_items
),

sellers as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_sellers
),

products as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_products
),

payments as (
    select * from PROJETO_OLIST_DB.ANALYTICS.fact_payments
),

geolocation as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_geolocation
),

item_agg as (
    select
        items.order_id,
        count(*) as item_count,
        sum(items.price) as total_price,
        sum(items.freight_value) as total_freight,
        avg(products.product_weight_g) as avg_product_weight_g,
        avg(products.product_volume_cm3) as avg_product_volume_cm3
    from items
    left join products on items.product_key = products.product_key
    group by items.order_id
),

primary_seller as (
    select order_id, seller_key
    from items
    qualify row_number() over (partition by order_id order by order_item_id) = 1
),

payment_agg as (
    select
        order_id,
        max(payment_installments) as payment_installments_max,
        sum(payment_value) as payment_value_total
    from payments
    group by order_id
),

customer_geo as (
    select
        customers.customer_key,
        customers.state,
        geolocation.lat,
        geolocation.lng
    from customers
    left join geolocation on customers.zip_code_prefix = geolocation.zip_code_prefix
),

seller_geo as (
    select
        sellers.seller_key,
        sellers.state,
        geolocation.lat,
        geolocation.lng
    from sellers
    left join geolocation on sellers.zip_code_prefix = geolocation.zip_code_prefix
)

select
    orders.order_id,
    orders.is_late,
    item_agg.total_price,
    item_agg.total_freight,
    item_agg.item_count,
    item_agg.avg_product_weight_g,
    item_agg.avg_product_volume_cm3,
    payment_agg.payment_installments_max,
    payment_agg.payment_value_total,
    orders.approval_delay_hours,
    orders.estimated_delivery_days,
    dayofweek(orders.order_purchase_timestamp) as purchase_dow,
    month(orders.order_purchase_timestamp) as purchase_month,
    haversine(customer_geo.lat, customer_geo.lng, seller_geo.lat, seller_geo.lng) as distance_km,
    iff(customer_geo.state = seller_geo.state, 1, 0) as same_state_flag,
    customer_geo.state as customer_state,
    seller_geo.state as seller_state
from orders
inner join item_agg on orders.order_id = item_agg.order_id
left join payment_agg on orders.order_id = payment_agg.order_id
left join primary_seller on orders.order_id = primary_seller.order_id
left join seller_geo on primary_seller.seller_key = seller_geo.seller_key
left join customer_geo on orders.customer_key = customer_geo.customer_key
where orders.order_status = 'delivered'
    and orders.order_delivered_customer_date is not null
    and orders.order_estimated_delivery_date is not null