import asyncio
from scrapers.naukri_scraper import NaukriScraper
from models.job_listing import SearchJobsParams

async def run():
    scraper = NaukriScraper()
    params = SearchJobsParams(keywords="python", location="india", sources=["naukri"])
    jobs = await scraper.scrape(params)
    print("Naukri jobs found:", len(jobs))
    for j in jobs[:3]:
        print(j.title, "-", j.company)

asyncio.run(run())
