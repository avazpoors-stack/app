from .conftest import auth_headers, register_otp


def test_shop_catalog_has_categories_and_filters(client):
    assert len(client.get('/api/v1/shop/categories').json()) == 8
    response = client.get('/api/v1/shop/products?category=gym')
    assert response.status_code == 200
    assert all(item['category'] == 'gym' for item in response.json())


def test_seller_can_create_pending_product_and_customer_can_mock_order(client):
    seller = register_otp(client, '09120000021', role='seller')
    product = client.post('/api/v1/shop/products', headers=auth_headers(seller), json={
        'name': 'دمبل نمونه', 'category': 'gym', 'brand': 'بدنه', 'price_toman': 100000, 'stock': 2,
    })
    assert product.status_code == 201
    assert product.json()['approved'] is False

    customer = register_otp(client, '09120000022', role='customer')
    order = client.post('/api/v1/shop/orders', headers={**auth_headers(customer), 'Idempotency-Key': 'checkout-12345'}, json={
        'items': [{'product_id': 'mock-band', 'quantity': 2, 'price_toman': 320000}],
    })
    assert order.status_code == 200
    assert order.json()['total_toman'] == 640000
    assert order.json()['status'] == 'payment_pending'
