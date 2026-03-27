from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks, Response
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import joblib
import numpy as np
import pandas as pd
import os
import io
from typing import Optional
# ─── Robust artifact loader ─────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORK_DIR = os.getcwd()

def find_artifact(filename: str) -> str:
    """Search for a pkl file across multiple likely locations."""
    candidates = [
        os.path.join(BASE_DIR, filename),
        os.path.join(WORK_DIR, filename),
        filename,
        os.path.join(BASE_DIR, "..", filename),
        os.path.join(WORK_DIR, "..", filename),
    ]
    for path in candidates:
        full = os.path.normpath(path)
        if os.path.exists(full):
            print(f"[OK] Found {filename} → {full}")
            return full
    searched = [os.path.normpath(c) for c in candidates]
    raise FileNotFoundError(f"Cannot find {filename}. Searched: {searched}")

def load_artifacts():
    try:
        m      = joblib.load(find_artifact("best_salary_model.pkl"))
        sc     = joblib.load(find_artifact("scaler.pkl"))
        le_g   = joblib.load(find_artifact("le_gender.pkl"))
        le_e   = joblib.load(find_artifact("le_education.pkl"))
        le_j   = joblib.load(find_artifact("le_jobtitle.pkl"))
        print("[OK] All model artifacts loaded.")
        return m, sc, le_g, le_e, le_j, None
    except Exception as exc:
        print(f"[ERROR] Artifact loading failed: {exc}")
        print(f"  BASE_DIR = {BASE_DIR}")
        print(f"  WORK_DIR = {WORK_DIR}")
        print(f"  Files in BASE_DIR: {os.listdir(BASE_DIR)}")
        return None, None, None, None, None, str(exc)

model, scaler, le_gender, le_education, le_jobtitle, LOAD_ERROR = load_artifacts()

# ─── FastAPI app ─────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Tech Salary Prediction API",
    description="""
## Nairobi Software Company — Tech Hiring Tool

Predicts expected annual salary for a tech employee based on their profile.

### Endpoints
- **POST /predict** — Predict salary for a single candidate
- **POST /retrain** — Upload new CSV data to retrain the model
- **GET /health** — Check API status and artifact loading
- **GET /model-info** — View current model details and valid input values

### Mission
Fair salary benchmarking for young tech talent in Kasarani & Nairobi, Kenya.
""",
    version="1.0.0",
)

# ─── CORS Middleware ──────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Pydantic Schemas ─────────────────────────────────────────────────────────────
class SalaryPredictionInput(BaseModel):
    gender: str = Field(..., description="Gender of the candidate", example="Male")
    education_level: str = Field(..., description="Highest education level", example="Bachelor's")
    job_title: str = Field(..., description="Job title / role", example="Software Engineer")
    years_of_experience: float = Field(
        ..., ge=0.0, le=50.0,
        description="Years of professional experience (0–50)",
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
    predicted_salary_usd: float
    predicted_salary_kes_annual: float
    predicted_salary_kes_monthly: float
    input_received: dict
    model_used: str


class RetrainResponse(BaseModel):
    status: str
    message: str
    rows_used: int
    new_model_r2: float


# ─── Helper ───────────────────────────────────────────────────────────────────────
def check_loaded():
    if model is None:
        raise HTTPException(
            status_code=503,
            detail=f"Model artifacts not loaded. Error: {LOAD_ERROR}. Check /health for details."
        )

def encode_input(data: SalaryPredictionInput) -> np.ndarray:
    check_loaded()

    if data.gender not in le_gender.classes_:
        raise HTTPException(422, f"Unknown gender '{data.gender}'. Valid: {list(le_gender.classes_)}")
    if data.education_level not in le_education.classes_:
        raise HTTPException(422, f"Unknown education level '{data.education_level}'. Valid: {list(le_education.classes_)}")
    if data.job_title not in le_jobtitle.classes_:
        raise HTTPException(422, f"Unknown job title '{data.job_title}'. Check /model-info for valid titles.")

    # Build a DataFrame with the original feature names the scaler expects to avoid
    # the "X does not have valid feature names" warning when the scaler was fitted
    # on a DataFrame.
    row_df = pd.DataFrame([
        {
            "Years of Experience": data.years_of_experience,
            "Gender_enc": le_gender.transform([data.gender])[0],
            "Education_enc": le_education.transform([data.education_level])[0],
            "JobTitle_enc": le_jobtitle.transform([data.job_title])[0],
        }
    ])
    return scaler.transform(row_df)


# ─── Routes ───────────────────────────────────────────────────────────────────────

@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Tech Salary Prediction API — Nairobi Hiring Tool",
        "docs": "/docs",
        "health": "/health",
        "predict": "POST /predict",
        "retrain": "POST /retrain",
    }


@app.get("/health", tags=["Health"])
async def health_check():
    files_present = {}
    for fname in ["best_salary_model.pkl", "scaler.pkl", "le_gender.pkl", "le_education.pkl", "le_jobtitle.pkl"]:
        try:
            path = find_artifact(fname)
            files_present[fname] = f"found at {path}"
        except FileNotFoundError:
            files_present[fname] = "MISSING"

    return {
        "status": "healthy" if model is not None else "degraded",
        "model_loaded": model is not None,
        "load_error": LOAD_ERROR,
        "base_dir": BASE_DIR,
        "work_dir": WORK_DIR,
        "files": files_present,
        "api_version": "1.0.0"
    }


@app.get("/model-info", tags=["Model"])
async def model_info():
    check_loaded()
    return {
        "model_type": type(model).__name__,
        "features": ["years_of_experience", "gender_encoded", "education_encoded", "jobtitle_encoded"],
        "target": "salary_usd",
        "known_genders": list(le_gender.classes_),
        "known_education_levels": list(le_education.classes_),
        "total_job_titles": len(le_jobtitle.classes_),
        "job_titles_sample": list(le_jobtitle.classes_[:20]),
        "all_job_titles": list(le_jobtitle.classes_),
    }


@app.post("/predict", response_model=SalaryPredictionOutput, tags=["Prediction"])
async def predict_salary(data: SalaryPredictionInput):
    """
    ## Predict Tech Employee Salary

    Provide candidate details to get a predicted annual salary in USD and KES.
    """
    try:
        row_scaled       = encode_input(data)
        predicted_usd    = float(model.predict(row_scaled)[0])
        kes_annual       = predicted_usd * 130.0
        kes_monthly      = kes_annual / 12.0

        return SalaryPredictionOutput(
            predicted_salary_usd=round(predicted_usd, 2),
            predicted_salary_kes_annual=round(kes_annual, 2),
            predicted_salary_kes_monthly=round(kes_monthly, 2),
            input_received=data.model_dump(),
            model_used=type(model).__name__,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(exc)}")


@app.post("/retrain", response_model=RetrainResponse, tags=["Retraining"])
async def retrain(
    file: UploadFile = File(..., description="CSV with columns: Gender, Education Level, Job Title, Years of Experience, Salary")
):
    """
    ## Retrain the Model with New Data

    Upload a CSV file. All three models are retrained and the best one is saved automatically.

    Required columns: `Gender, Education Level, Job Title, Years of Experience, Salary`
    """
    global model, scaler, le_gender, le_education, le_jobtitle, LOAD_ERROR

    if not file.filename.endswith(".csv"):
        raise HTTPException(400, "Only CSV files accepted.")

    try:
        contents = await file.read()
        df = pd.read_csv(io.StringIO(contents.decode("utf-8")))
    except Exception as exc:
        raise HTTPException(400, f"Could not parse CSV: {exc}")

    required = {"Gender", "Education Level", "Job Title", "Years of Experience", "Salary"}
    if not required.issubset(df.columns):
        raise HTTPException(422, f"CSV must contain columns: {required}. Found: {list(df.columns)}")

    try:
        from sklearn.model_selection import train_test_split
        from sklearn.preprocessing import LabelEncoder, StandardScaler
        from sklearn.ensemble import RandomForestRegressor
        from sklearn.linear_model import SGDRegressor
        from sklearn.tree import DecisionTreeRegressor
        from sklearn.metrics import r2_score

        df = df.dropna()
        df = df.drop(columns=["Age"], errors="ignore")

        new_le_g = LabelEncoder()
        new_le_e = LabelEncoder()
        new_le_j = LabelEncoder()

        df["Gender_enc"]    = new_le_g.fit_transform(df["Gender"])
        df["Education_enc"] = new_le_e.fit_transform(df["Education Level"])
        df["JobTitle_enc"]  = new_le_j.fit_transform(df["Job Title"])
        df = df.drop(columns=["Gender", "Education Level", "Job Title"])

        X = df.drop(columns=["Salary"])
        y = df["Salary"]

        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        new_scaler  = StandardScaler()
        X_train_sc  = new_scaler.fit_transform(X_train)
        X_test_sc   = new_scaler.transform(X_test)

        candidates = {
            "RandomForest": RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1),
            "DecisionTree": DecisionTreeRegressor(max_depth=8, random_state=42),
            "SGD":          SGDRegressor(max_iter=500, random_state=42),
        }

        best_name, best_trained, best_r2 = None, None, -999
        for name, m in candidates.items():
            m.fit(X_train_sc, y_train)
            r2 = r2_score(y_test, m.predict(X_test_sc))
            if r2 > best_r2:
                best_r2, best_name, best_trained = r2, name, m
        # If no candidate improved the default (this can happen with very small datasets),
        # fallback to training a RandomForest on the entire dataset instead of saving None.
        if best_trained is None:
            from sklearn.ensemble import RandomForestRegressor
            # Refit scaler on the full data and train on all available rows.
            new_scaler = StandardScaler()
            X_full_sc = new_scaler.fit_transform(X)
            fallback = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
            fallback.fit(X_full_sc, y)
            best_trained = fallback
            best_name = "RandomForest_full"
            try:
                best_r2 = float(r2_score(y, fallback.predict(X_full_sc)))
            except Exception:
                best_r2 = -999

        save_dir = BASE_DIR
        joblib.dump(best_trained, os.path.join(save_dir, "best_salary_model.pkl"))
        joblib.dump(new_scaler,   os.path.join(save_dir, "scaler.pkl"))
        joblib.dump(new_le_g,     os.path.join(save_dir, "le_gender.pkl"))
        joblib.dump(new_le_e,     os.path.join(save_dir, "le_education.pkl"))
        joblib.dump(new_le_j,     os.path.join(save_dir, "le_jobtitle.pkl"))

        model        = best_trained
        scaler       = new_scaler
        le_gender    = new_le_g
        le_education = new_le_e
        le_jobtitle  = new_le_j
        LOAD_ERROR   = None

        return RetrainResponse(
            status="success",
            message=f"Retrained successfully. Best model: {best_name}",
            rows_used=len(df),
            new_model_r2=round(best_r2, 4),
        )

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(500, f"Retraining failed: {str(exc)}")