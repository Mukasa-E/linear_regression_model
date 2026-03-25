Tech Salary Prediction — Nairobi Software Company Hiring Tool

Mission: To use skills in software engineering and app development to build practical, user-friendly digital solutions that improve services and infrastructure in Nairobi, Kenya — starting a software company that helps local businesses operate more efficiently while creating employment opportunities for young people through innovation and skills development.

Problem: A Nairobi tech startup needs data-driven salary benchmarks to hire young talent fairly — offering competitive rates without burning runway. This model predicts expected tech employee salary based on education, experience, job title, and gender, giving founders a fair hiring anchor in a competitive market.

Dataset Selected: Salary Prediction Dataset — Kaggle — 6,704 records of tech employees with features: Age, Gender, Education Level, Job Title, Years of Experience - Salary (USD). Rich in volume and variety with both categorical and numerical features.

Models Trained

ModelDescriptionLinear Regression-(SGD)Gradient descent with loss tracked per epochDecision 

Tree Regressormax_depth=8, min_samples_split=10Random 

Forest Regressor150 trees, max_depth=10

The best-performing model (lowest Test MSE) is automatically saved as best_salary_model.pkl.

Key Visualizations

Salary distribution histogram + education level comparison
Years of experience vs salary scatter (coloured by age)

Job title salary box plots (top 8 roles)

Correlation heatmap - confirms dropping Age (r=0.85 with Experience)

Train vs Test loss curve over 150 epochs

Before/After scatter plot with regression line

How to Run

Download Salary_Data.csv from the Kaggle

Place it in summative/linear_regression/

Open multivariate.ipynb in Google Colab or Jupyter

Run all cells top to bottom

Requirements
pip install numpy pandas matplotlib seaborn scikit-learn joblib

# Tech Salary Prediction API

FastAPI backend for the Nairobi Software Company Hiring Tool.
Predicts expected tech employee salary to help Nairobi startups benchmark pay fairly.

## Live API (after deploying to Render)

- Swagger UI (test all endpoints): `https://nairobi-salary-predictor.onrender.com/docs`
- Prediction endpoint: `https://nairobi-salary-predictor.onrender.com/predict`
- Retraining endpoint: `https://nairobi-salary-predictor.onrender.com/retrain`
- Health check: `https://nairobi-salary-predictor.onrender.com/health`


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
