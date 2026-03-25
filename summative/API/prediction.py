from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import joblib
import numpy as np
import pandas as pd
import os
import io
from typing import Optional

# Load model artifacts on startup

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def load_artifacts():
    model   = joblib.load(os.path.join(BASE_DIR, "best_salary_model.pkl"))
    scaler  = joblib.load(os.path.join(BASE_DIR, "scaler.pkl"))
    le_gen  = joblib.load(os.path.join(BASE_DIR, "le_gender.pkl"))
    le_edu  = joblib.load(os.path.join(BASE_DIR, "le_education.pkl"))
    le_job  = joblib.load(os.path.join(BASE_DIR, "le_jobtitle.pkl"))
    return model, scaler, le_gen, le_edu, le_job

model, scaler, le_gender, le_education, le_jobtitle = load_artifacts()

# FastAPI app 
app = FastAPI(
    title="Tech Salary Prediction API",
    description="""
## 💼 Nairobi Software Company — Tech Hiring Tool

Predicts expected annual salary for a tech employee based on their profile.

### Endpoints
- **POST /predict** — Predict salary for a single candidate
- **POST /retrain** — Upload new CSV data to retrain the model
- **GET /health** — Check API status
- **GET /model-info** — View current model details

### Mission
Fair salary benchmarking for young tech talent in Nairobi, Kenya.
""",
    version="1.0.0",
)

# CORS Middleware

origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8080",
    "http://localhost:8000",
    "https://localhost",
    "*",  # Allow all for public API — tighten to Flutter app URL in production
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,   # must be False when allow_origins includes "*"
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic Input Schema

class SalaryPredictionInput(BaseModel):
    gender: str = Field(
        ...,
        description="Gender of the candidate",
        example="Male"
    )
    education_level: str = Field(
        ...,
        description="Highest education level attained",
        example="Bachelor's"
    )
    job_title: str = Field(
        ...,
        description="Job title / role applied for",
        example="Software Engineer"
    )
    years_of_experience: float = Field(
        ...,
        ge=0.0,
        le=50.0,
        description="Total years of professional experience (0–50)",
        example=3.0
    )

    class Config:
        json_schema_extra = {
            "example": {
                "gender": "Female",
                "education_level": "Master's",
                "job_title": "Data Scientist",
                "years_of_experience": 4.5
            }
        }


class SalaryPredictionOutput(BaseModel):
    predicted_salary_usd: float = Field(..., description="Predicted annual salary in USD")
    predicted_salary_kes_annual: float = Field(..., description="Predicted annual salary in KES")
    predicted_salary_kes_monthly: float = Field(..., description="Predicted monthly salary in KES")
    input_received: dict = Field(..., description="Echo of the input for confirmation")
    model_used: str = Field(..., description="Name of the model that made the prediction")


class RetrainResponse(BaseModel):
    status: str
    message: str
    rows_used: int
    new_model_r2: float


# Helper: encode a single input row 
def encode_input(data: SalaryPredictionInput) -> np.ndarray:
    """Encode and scale a single prediction input using saved LabelEncoders."""

    # Validate that values exist in the encoder's known classes
    if data.gender not in le_gender.classes_:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown gender '{data.gender}'. Valid values: {list(le_gender.classes_)}"
        )
    if data.education_level not in le_education.classes_:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown education level '{data.education_level}'. Valid values: {list(le_education.classes_)}"
        )
    if data.job_title not in le_jobtitle.classes_:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown job title '{data.job_title}'. Valid values (sample): {list(le_jobtitle.classes_[:10])}..."
        )

    gender_enc  = le_gender.transform([data.gender])[0]
    edu_enc     = le_education.transform([data.education_level])[0]
    job_enc     = le_jobtitle.transform([data.job_title])[0]

    # Feature order must match training: Years of Experience, Gender_enc, Education_enc, JobTitle_enc
    row = np.array([[data.years_of_experience, gender_enc, edu_enc, job_enc]])
    row_scaled = scaler.transform(row)
    return row_scaled


# Routes

@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Tech Salary Prediction API — Nairobi Hiring Tool",
        "docs": "/docs",
        "health": "/health",
        "predict": "/predict",
    }


@app.get("/favicon.ico", include_in_schema=False)
async def favicon():
    # Avoid browser-generated 404 noise when no favicon file is provided.
    return Response(status_code=204)


@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "scaler_loaded": scaler is not None,
        "api_version": "1.0.0"
    }


@app.get("/model-info", tags=["Model"])
async def model_info():
    return {
        "model_type": type(model).__name__,
        "features": ["years_of_experience", "gender", "education_level", "job_title"],
        "target": "salary_usd",
        "known_genders": list(le_gender.classes_),
        "known_education_levels": list(le_education.classes_),
        "known_job_titles_count": len(le_jobtitle.classes_),
        "known_job_titles_sample": list(le_jobtitle.classes_[:15]),
    }


@app.post("/predict", response_model=SalaryPredictionOutput, tags=["Prediction"])
async def predict_salary(data: SalaryPredictionInput):
    """
    ## Predict Tech Employee Salary

    Provide candidate details and receive a predicted annual salary in both USD and KES.

    ### Input fields
    - **gender**: "Male" or "Female"
    - **education_level**: "High School" | "Bachelor's" | "Master's" | "PhD"
    - **job_title**: Job title string (see /model-info for full list)
    - **years_of_experience**: Float between 0.0 and 50.0

    ### Output
    Returns predicted salary in USD and KES (annual + monthly).
    """
    try:
        row_scaled = encode_input(data)
        predicted_usd = float(model.predict(row_scaled)[0])

        KES_RATE = 130.0
        predicted_kes_annual  = predicted_usd * KES_RATE
        predicted_kes_monthly = predicted_kes_annual / 12

        return SalaryPredictionOutput(
            predicted_salary_usd=round(predicted_usd, 2),
            predicted_salary_kes_annual=round(predicted_kes_annual, 2),
            predicted_salary_kes_monthly=round(predicted_kes_monthly, 2),
            input_received=data.model_dump(),
            model_used=type(model).__name__,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


# Retraining endpoint

def retrain_model_task(df: pd.DataFrame):
    """Background task: retrain and overwrite the saved model with new data."""
    global model, scaler, le_gender, le_education, le_jobtitle

    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import LabelEncoder, StandardScaler
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.linear_model import SGDRegressor
    from sklearn.tree import DecisionTreeRegressor
    from sklearn.metrics import r2_score, mean_squared_error

    # Expect columns: Gender, Education Level, Job Title, Years of Experience, Salary
    required = {"Gender", "Education Level", "Job Title", "Years of Experience", "Salary"}
    if not required.issubset(df.columns):
        raise ValueError(f"CSV must contain columns: {required}")

    df = df.dropna()
    df = df.drop(columns=["Age"], errors="ignore")

    new_le_gen = LabelEncoder()
    new_le_edu = LabelEncoder()
    new_le_job = LabelEncoder()

    df["Gender_enc"]    = new_le_gen.fit_transform(df["Gender"])
    df["Education_enc"] = new_le_edu.fit_transform(df["Education Level"])
    df["JobTitle_enc"]  = new_le_job.fit_transform(df["Job Title"])
    df = df.drop(columns=["Gender", "Education Level", "Job Title"])

    X = df.drop(columns=["Salary"])
    y = df["Salary"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    new_scaler = StandardScaler()
    X_train_sc = new_scaler.fit_transform(X_train)
    X_test_sc  = new_scaler.transform(X_test)

    # Train all three — pick best
    candidates = {
        "RandomForest": RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1),
        "DecisionTree": DecisionTreeRegressor(max_depth=8, random_state=42),
        "SGD": SGDRegressor(max_iter=500, random_state=42),
    }

    best_name, best_trained, best_r2 = None, None, -999
    for name, m in candidates.items():
        m.fit(X_train_sc, y_train)
        r2 = r2_score(y_test, m.predict(X_test_sc))
        if r2 > best_r2:
            best_r2, best_name, best_trained = r2, name, m

    # Overwrite saved artifacts
    joblib.dump(best_trained, os.path.join(BASE_DIR, "best_salary_model.pkl"))
    joblib.dump(new_scaler,   os.path.join(BASE_DIR, "scaler.pkl"))
    joblib.dump(new_le_gen,   os.path.join(BASE_DIR, "le_gender.pkl"))
    joblib.dump(new_le_edu,   os.path.join(BASE_DIR, "le_education.pkl"))
    joblib.dump(new_le_job,   os.path.join(BASE_DIR, "le_jobtitle.pkl"))

    # Reload in memory
    model, scaler      = best_trained, new_scaler
    le_gender          = new_le_gen
    le_education       = new_le_edu
    le_jobtitle        = new_le_job

    return best_name, best_r2, len(df)


@app.post("/retrain", response_model=RetrainResponse, tags=["Retraining"])
async def retrain(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="CSV file with columns: Gender, Education Level, Job Title, Years of Experience, Salary")
):
    """
    ## Retrain the Model with New Data

    Upload a CSV file containing new labelled salary data.
    The API will retrain all three models (Random Forest, Decision Tree, SGD),
    select the best one, and replace the saved model automatically.

    ### Required CSV columns
    `Gender, Education Level, Job Title, Years of Experience, Salary`

    ### Notes
    - Age column is optional and will be dropped automatically
    - Minimum recommended: 100 rows
    - Retraining happens synchronously so the updated model is ready immediately
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are accepted.")

    try:
        contents = await file.read()
        df = pd.read_csv(io.StringIO(contents.decode("utf-8")))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not parse CSV: {str(e)}")

    try:
        best_name, best_r2, n_rows = retrain_model_task(df)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Retraining failed: {str(e)}")

    return RetrainResponse(
        status="success",
        message=f"Model retrained successfully. Best model: {best_name}",
        rows_used=n_rows,
        new_model_r2=round(best_r2, 4),
    )