"""تست جستجوی سراسری P3."""


def test_search_finds_exercise_without_auth(client):
    response = client.get("/api/v1/search", params={"q": "اسكوات"})
    assert response.status_code == 200
    body = response.json()
    assert body["total"] >= 1
    assert body["results"][0]["title"] == "اسکوات"
    assert body["results"][0]["category"] == "exercise"


def test_search_category_filter(client):
    response = client.get(
        "/api/v1/search",
        params={"q": "کش", "category": "product", "limit": 5},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["results"]
    assert all(item["category"] == "product" for item in body["results"])
    assert body["results"][0]["coming_soon"] is True


def test_search_rejects_short_query(client):
    response = client.get("/api/v1/search", params={"q": "ا"})
    assert response.status_code == 422
