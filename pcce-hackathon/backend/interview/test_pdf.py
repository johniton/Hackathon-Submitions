import requests, json

profile = {
    "name": "Harsh Gaonker",
    "summary": "Full stack dev",
    "experience": [{"title": "Dev", "company": "Tech", "bullets": ["Did stuff"]}]
}
res = requests.post("http://localhost:8002/resume/export/pdf", data={
    "resume_json": json.dumps(profile),
    "template_name": "modern"
})
print(res.status_code)
if res.status_code == 200:
    print("PDF size:", len(res.content))
else:
    print(res.text)
