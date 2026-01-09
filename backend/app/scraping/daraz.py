from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import time


def scrape_daraz_phones():
    url = "https://www.daraz.pk/smartphones/"
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()))
    driver.get(url)

    time.sleep(6)

    products = []

    items = driver.find_elements(By.CSS_SELECTOR, ".Bm3ON")

    for item in items[:15]:
        try:
            name = item.find_element(By.CSS_SELECTOR, "._4rR01T").text
            price = item.find_element(By.CSS_SELECTOR, ".aBrP0").text

            products.append({
                "name": name,
                "price": price,
                "category": "Phone",
                "source": "Daraz"
            })
        except:
            continue

    driver.quit()
    return products
