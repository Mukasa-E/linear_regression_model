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

- Swagger UI (test all endpoints): `https://salary-prediction-api-lbh8.onrender.com/`


- Health check: `https://salary-prediction-api-lbh8.onrender.com/health`


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
	# Tech Salary Prediction — Nairobi Software Company Hiring Tool

	Repository: https://github.com/Mukasa-E/linear_regression_model

	Notebook: `summative/linear_regression/multivariate.ipynb`
	API code: `summative/API/`
	Flutter app: `summative/FlutterApp/flutter_app/`

	## Mission
	Build a practical salary-benchmarking tool for Nairobi tech employers to make fair, data-driven hiring decisions.
	Problem: Small startups need fast, reliable salary estimates to avoid overpaying or underpaying while conserving runway.

	Dataset: Salary Prediction Dataset — Kaggle (6,704 records). Features: Age, Gender, Education Level, Job Title, Years of Experience, Salary (USD).

	Model artifacts built with scikit-learn 1.6.1 (see requirements.txt). Use deployed API to avoid local pickle incompatibility.

	
	### Example /predict request (JSON)
	```json
	{
		"gender": "Female",
		"education_level": "Master's",
		"job_title": "Data Scientist",
		"years_of_experience": 4.5
	}
	```

	### Example /retrain (multipart form)
	```bash
	curl -X POST "https://salary-prediction-api-lbh8.onrender.com/retrain" -F "file=@C:\temp\small_salary.csv"
	```

	---

	## Demo
	Demo video: https://youtu.be/bK55vKJcJe8

	---

	## Run the backend locally
	1. Open a terminal in `summative/API`
	2. (Optional) Create & activate a virtualenv

	Windows (cmd.exe):
	```cmd
	python -m venv .venv
	.venv\Scripts\activate
	```

	3. Install dependencies
	```cmd
	pip install -r requirements.txt
	```

	4. Start the API
	```cmd
	uvicorn prediction:app --reload --host 0.0.0.0 --port 8000
	```

	Open http://localhost:8000/docs to test endpoints with Swagger UI.

	---

	## Run the mobile app (Flutter)
	1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
	2. Open a terminal in `summative/FlutterApp/flutter_app`
	3. Fetch packages:
	```bash
	flutter pub get
	```
	4. Run on Chrome (web):
	```bash
	flutter run -d chrome
	```
	Or run on an emulator/device:
	```bash
	flutter devices
	flutter run -d <device-id>
	```

	

	

	