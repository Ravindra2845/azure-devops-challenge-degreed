# Daily Wisdom - Azure DevOps Challenge

## Overview
A High-Availability web application deployed on Azure using Terraform. The app retrieves random quotes from an Azure SQL Database.

## Architecture
* **App Service:** Hosted on Azure Web Apps (Linux/Python).
* **Database:** Azure SQL Database (Serverless/S0).
* **Security:**
    * **Key Vault:** Stores sensitive SQL credentials.
    * **Firewall:** Whitelisted for Azure Services.
    * **Networking:** Secure connection via connection strings injected as environment variables.

## Infrastructure Decisions (Important)
**Constraint:** The available Azure Free Trial subscription enforced a strict **0 vCPU quota** for Standard/Basic App Service Plans in major regions, preventing a standard production deployment.

**Solution:**
To deliver a functional solution within these constraints, I adapted the Infrastructure as Code (Terraform) to:
1.  Use the **F1 (Free Tier)** App Service Plan.
2.  Deploy to the **Central US** region (where quotas were available).
3.  Utilize **Password Authentication** for the Database connection to ensure reliability given the limited networking capabilities of the Free Tier.

## How to Deploy
1.  `cd terraform`
2.  `terraform init`
3.  `terraform apply`
4.  `cd ../app`
5.  `az webapp deployment source config-zip ...`
