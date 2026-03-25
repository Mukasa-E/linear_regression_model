# Tech Salary Prediction API

FastAPI backend for the Nairobi Software Company Hiring Tool.
Predicts expected tech employee salary to help Kasarani and Nairobi startups benchmark pay fairly.

## Live API (after deploying to Render)

- Swagger UI (test all endpoints): `https://your-app.onrender.com/docs`
- Prediction endpoint: `https://your-app.onrender.com/predict`
- Retraining endpoint: `https://your-app.onrender.com/retrain`
- Health check: `https://your-app.onrender.com/health`

Replace `your-app` with your actual Render service name.

## Endpoints

### POST /predict
Predict salary for a candidate.

Request body:

```json
{
	"gender": "Female",
	"education_level": "Master's",
	"job_title": "Data Scientist",
	"years_of_experience": 4.5
}
```

Response example:

```json
{
	"predicted_salary_usd": 95000.0,
	"predicted_salary_kes_annual": 12350000.0,
	"predicted_salary_kes_monthly": 1029166.67,
	"input_received": {
		"gender": "Female",
		"education_level": "Master's",
		"job_title": "Data Scientist",
		"years_of_experience": 4.5
	},
	"model_used": "RandomForestRegressor"
}
```

### POST /retrain
Upload a new CSV file to retrain the model.

- Accepts `multipart/form-data` with a `file` field
- CSV must contain: `Gender, Education Level, Job Title, Years of Experience, Salary`
- All three models are retrained and the best one is saved automatically

### GET /model-info
Returns current model type, feature list, and valid categorical input values.

### GET /health
Returns a health payload so you can verify the API is running.

## Run Locally

```bash
# 1. Install dependencies
python -m pip install -r requirements.txt

# 2. Start the server (this project uses prediction.py)
uvicorn prediction:app --reload

# 3. Open docs
# http://localhost:8000/docs
```

## Should You Deploy First?

No. First confirm local Swagger works at `/docs` and test `/predict` once.
Then push to GitHub and deploy to Render.
