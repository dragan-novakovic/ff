using Npgsql;

internal static class CompanyWorkforceEndpoints
{
    public static void MapCompanyWorkforceEndpoints(this WebApplication app)
    {
        app.MapGet("/workforce/jobs", async (
            string? actorPlayerId,
            ProductionStore production) =>
        {
            if (string.IsNullOrWhiteSpace(actorPlayerId))
            {
                return Results.BadRequest(new ErrorResponse("Actor player id is required."));
            }

            return Results.Ok(await production.ListWorkforceJobsAsync(actorPlayerId));
        }).WithName("ListWorkforceJobs");

        app.MapGet("/companies/{companyId}/jobs", async (
            string companyId,
            string? actorPlayerId,
            ProductionStore production) =>
        {
            if (string.IsNullOrWhiteSpace(actorPlayerId))
            {
                return Results.BadRequest(new ErrorResponse("Actor player id is required."));
            }

            return ToStoreResult(await production.ListCompanyJobPostingsAsync(companyId, actorPlayerId));
        }).WithName("ListCompanyJobPostings");

        app.MapGet("/companies/{companyId}/jobs/{jobId}", async (
            string companyId,
            string jobId,
            string? actorPlayerId,
            ProductionStore production) =>
        {
            if (string.IsNullOrWhiteSpace(actorPlayerId))
            {
                return Results.BadRequest(new ErrorResponse("Actor player id is required."));
            }

            return ToStoreResult(await production.GetCompanyJobPostingAsync(companyId, jobId, actorPlayerId));
        }).WithName("GetCompanyJobPosting");

        app.MapPost("/companies/{companyId}/jobs", async (
            string companyId,
            CompanyJobPostingRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.CreateCompanyJobPostingAsync(companyId, request)))
            .WithName("CreateCompanyJobPosting");

        app.MapPost("/companies/{companyId}/jobs/{jobId}", async (
            string companyId,
            string jobId,
            CompanyJobPostingRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.UpdateCompanyJobPostingAsync(companyId, jobId, request)))
            .WithName("UpdateCompanyJobPosting");

        app.MapPost("/companies/{companyId}/jobs/{jobId}/close", async (
            string companyId,
            string jobId,
            CompanyActorRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.CloseCompanyJobPostingAsync(companyId, jobId, request.ActorPlayerId)))
            .WithName("CloseCompanyJobPosting");

        app.MapPost("/companies/{companyId}/jobs/{jobId}/work", async (
            string companyId,
            string jobId,
            CompanyWorkRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.BeginCompanyWorkAsync(companyId, jobId, request)))
            .WithName("BeginCompanyWork");

        app.MapPost("/companies/{companyId}/jobs/{jobId}/work/{workId}/complete", async (
            string companyId,
            string jobId,
            string workId,
            CompanyWorkCompletionRequest request,
            ProductionStore production) =>
            ToStoreResult(await production.CompleteCompanyWorkAsync(companyId, jobId, workId, request)))
            .WithName("CompleteCompanyWork");
    }

    private static IResult ToStoreResult<T>(StoreResult<T> result) where T : class
    {
        if (result.StatusCode is >= StatusCodes.Status200OK and < StatusCodes.Status300MultipleChoices)
        {
            return result.StatusCode == StatusCodes.Status200OK
                ? Results.Ok(result.Value)
                : Results.Json(result.Value, statusCode: result.StatusCode);
        }

        return result.StatusCode == StatusCodes.Status404NotFound
            ? Results.NotFound(new ErrorResponse(result.Message ?? "Resource was not found."))
            : Results.Json(
                new ErrorResponse(result.Message ?? "Request failed."),
                statusCode: result.StatusCode);
    }
}

internal sealed partial class ProductionStore
{
    private const int MaximumJobWageGold = 10_000;
    private const int MaximumJobRequiredEnergy = 100;
    private const int MaximumJobDailyLimit = 20;
    private const int MaximumJobProductivityReward = 100;
    private const string LaborCreditItemId = "labor_credit";

    public async Task<CompanyJobListResponse> ListWorkforceJobsAsync(string actorPlayerId)
    {
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var jobs = await ReadAllActiveCompanyJobPostingsAsync(connection, null, normalizedActorId);
        return new CompanyJobListResponse(
            CompanyId: null,
            Jobs: jobs.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow);
    }

    public async Task<StoreResult<CompanyJobListResponse>> ListCompanyJobPostingsAsync(
        string companyId,
        string actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        if (!await CompanyExistsAsync(connection, null, normalizedCompanyId))
        {
            return StoreResult<CompanyJobListResponse>.NotFound("Company was not found.");
        }

        var role = await ReadCompanyMemberRoleAsync(connection, null, normalizedCompanyId, normalizedActorId);
        var jobs = await ReadCompanyJobPostingsAsync(
            connection,
            null,
            normalizedCompanyId,
            normalizedActorId,
            includeInactive: CanManageCompany(role));
        return StoreResult<CompanyJobListResponse>.Ok(new CompanyJobListResponse(
            CompanyId: normalizedCompanyId,
            Jobs: jobs.ToArray(),
            UpdatedAt: DateTimeOffset.UtcNow));
    }

    public async Task<StoreResult<CompanyJobPostingDto>> GetCompanyJobPostingAsync(
        string companyId,
        string jobId,
        string actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        await using var connection = await _dataSource.OpenConnectionAsync();
        var job = await ReadCompanyJobPostingAsync(
            connection,
            null,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        if (job is null)
        {
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyJobPostingDto>.NotFound("Company job was not found.")
                : StoreResult<CompanyJobPostingDto>.NotFound("Company was not found.");
        }

        if (!job.IsActive)
        {
            var role = await ReadCompanyMemberRoleAsync(connection, null, normalizedCompanyId, normalizedActorId);
            if (!CanManageCompany(role))
            {
                return StoreResult<CompanyJobPostingDto>.Forbidden("Only company managers can view inactive jobs.");
            }
        }

        return StoreResult<CompanyJobPostingDto>.Ok(job);
    }

    public async Task<StoreResult<CompanyJobMutationResponse>> CreateCompanyJobPostingAsync(
        string companyId,
        CompanyJobPostingRequest request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var validation = ValidateCompanyJobPostingRequest(request);
        if (validation is not null)
        {
            return StoreResult<CompanyJobMutationResponse>.BadRequest(validation);
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyJobMutationResponse>.Forbidden("You must be a company member to post jobs.")
                : StoreResult<CompanyJobMutationResponse>.NotFound("Company was not found.");
        }

        if (!CanManageCompany(actorRole))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyJobMutationResponse>.Forbidden("Only owners and managers can post company jobs.");
        }

        var jobId = $"wjob-{Guid.NewGuid():N}";
        var status = request.IsActive == false ? "inactive" : "active";
        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.company_job_postings (
                job_id, company_id, title, description, wage_gold, required_energy,
                daily_limit, productivity_reward, status, created_by_player_id,
                created_at, updated_at
            )
            VALUES (
                @job_id, @company_id, @title, @description, @wage_gold, @required_energy,
                @daily_limit, @productivity_reward, @status, @created_by_player_id,
                @created_at, @updated_at
            );
            """, connection, transaction))
        {
            AddCompanyJobPostingParameters(insert, jobId, normalizedCompanyId, normalizedActorId, request, status, now);
            await insert.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var job = await ReadCompanyJobPostingAsync(
            connection,
            transaction,
            normalizedCompanyId,
            jobId,
            normalizedActorId);
        var assets = await ReadCompanyAssetsAsync(
            connection,
            transaction,
            normalizedCompanyId,
            now,
            normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyJobMutationResponse>.Ok(new CompanyJobMutationResponse(
            Completed: true,
            Message: $"Posted {job!.Title} for {job.WageGold} gold per shift.",
            Job: job,
            Assets: assets));
    }

    public async Task<StoreResult<CompanyJobMutationResponse>> UpdateCompanyJobPostingAsync(
        string companyId,
        string jobId,
        CompanyJobPostingRequest request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var validation = ValidateCompanyJobPostingRequest(request);
        if (validation is not null)
        {
            return StoreResult<CompanyJobMutationResponse>.BadRequest(validation);
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyJobMutationResponse>.Forbidden("You must be a company member to update jobs.")
                : StoreResult<CompanyJobMutationResponse>.NotFound("Company was not found.");
        }

        if (!CanManageCompany(actorRole))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyJobMutationResponse>.Forbidden("Only owners and managers can update company jobs.");
        }

        var existing = await ReadCompanyJobPostingForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        if (existing is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyJobMutationResponse>.NotFound("Company job was not found.");
        }

        var status = existing.Status == "closed"
            ? "closed"
            : request.IsActive == false ? "inactive" : "active";
        await using (var update = new NpgsqlCommand("""
            UPDATE production.company_job_postings
            SET title = @title,
                description = @description,
                wage_gold = @wage_gold,
                required_energy = @required_energy,
                daily_limit = @daily_limit,
                productivity_reward = @productivity_reward,
                status = @status,
                updated_at = @updated_at,
                closed_at = CASE WHEN @status = 'closed' THEN COALESCE(closed_at, @updated_at) ELSE closed_at END
            WHERE company_id = @company_id AND job_id = @job_id;
            """, connection, transaction))
        {
            AddCompanyJobPostingParameters(update, normalizedJobId, normalizedCompanyId, normalizedActorId, request, status, now);
            await update.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var job = await ReadCompanyJobPostingAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        var assets = await ReadCompanyAssetsAsync(
            connection,
            transaction,
            normalizedCompanyId,
            now,
            normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyJobMutationResponse>.Ok(new CompanyJobMutationResponse(
            Completed: true,
            Message: status == "closed"
                ? $"{job!.Title} is closed and cannot be reactivated."
                : $"{job!.Title} is now {status}.",
            Job: job,
            Assets: assets));
    }

    public async Task<StoreResult<CompanyJobMutationResponse>> CloseCompanyJobPostingAsync(
        string companyId,
        string jobId,
        string? actorPlayerId)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedActorId = NormalizePlayerId(actorPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<CompanyJobMutationResponse>.BadRequest("Actor player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var actorRole = await ReadCompanyMemberRoleAsync(connection, transaction, normalizedCompanyId, normalizedActorId);
        if (actorRole is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyJobMutationResponse>.Forbidden("You must be a company member to close jobs.")
                : StoreResult<CompanyJobMutationResponse>.NotFound("Company was not found.");
        }

        if (!CanManageCompany(actorRole))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyJobMutationResponse>.Forbidden("Only owners and managers can close company jobs.");
        }

        var existing = await ReadCompanyJobPostingForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        if (existing is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyJobMutationResponse>.NotFound("Company job was not found.");
        }

        if (existing.Status != "closed")
        {
            await using var close = new NpgsqlCommand("""
                UPDATE production.company_job_postings
                SET status = 'closed',
                    closed_at = COALESCE(closed_at, @closed_at),
                    updated_at = @updated_at
                WHERE company_id = @company_id AND job_id = @job_id;
                """, connection, transaction);
            close.Parameters.AddWithValue("company_id", normalizedCompanyId);
            close.Parameters.AddWithValue("job_id", normalizedJobId);
            close.Parameters.AddWithValue("closed_at", now);
            close.Parameters.AddWithValue("updated_at", now);
            await close.ExecuteNonQueryAsync();
        }

        await TouchCompanyAsync(connection, transaction, normalizedCompanyId, now);
        var job = await ReadCompanyJobPostingAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        var assets = await ReadCompanyAssetsAsync(
            connection,
            transaction,
            normalizedCompanyId,
            now,
            normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyJobMutationResponse>.Ok(new CompanyJobMutationResponse(
            Completed: true,
            Message: $"{job!.Title} is closed.",
            Job: job,
            Assets: assets));
    }

    public async Task<StoreResult<CompanyWorkResult>> BeginCompanyWorkAsync(
        string companyId,
        string jobId,
        CompanyWorkRequest request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        var idempotencyKey = NormalizeIdempotencyKey(request.IdempotencyKey);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<CompanyWorkResult>.BadRequest("Actor player id is required.");
        }

        if (idempotencyKey is null)
        {
            return StoreResult<CompanyWorkResult>.BadRequest("Idempotency key is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;
        var workDate = DateOnly.FromDateTime(now.UtcDateTime);

        var existingWork = await ReadCompanyWorkRecordByIdempotencyForUpdateAsync(connection, transaction, idempotencyKey);
        if (existingWork is not null)
        {
            if (!string.Equals(existingWork.CompanyId, normalizedCompanyId, StringComparison.Ordinal) ||
                !string.Equals(existingWork.JobId, normalizedJobId, StringComparison.Ordinal) ||
                !string.Equals(existingWork.PlayerId, normalizedActorId, StringComparison.Ordinal))
            {
                await transaction.RollbackAsync();
                return StoreResult<CompanyWorkResult>.Conflict("Idempotency key was already used for a different work record.");
            }

            var existingJob = await ReadCompanyJobPostingAsync(
                connection,
                transaction,
                existingWork.CompanyId,
                existingWork.JobId,
                normalizedActorId);
            var existingAssets = await ReadCompanyAssetsAsync(
                connection,
                transaction,
                existingWork.CompanyId,
                now,
                existingWork.PlayerId);
            await transaction.CommitAsync();
            return StoreResult<CompanyWorkResult>.Ok(new CompanyWorkResult(
                Completed: true,
                Message: existingWork.Status == "paid"
                    ? "Company work was already paid."
                    : "Company work is waiting for wallet credit completion.",
                Job: existingJob!,
                WorkRecord: existingWork,
                Assets: existingAssets));
        }

        var job = await ReadCompanyJobPostingForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        if (job is null)
        {
            await transaction.RollbackAsync();
            return await CompanyExistsAsync(connection, null, normalizedCompanyId)
                ? StoreResult<CompanyWorkResult>.NotFound("Company job was not found.")
                : StoreResult<CompanyWorkResult>.NotFound("Company was not found.");
        }

        if (!job.IsActive)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.Conflict("Company job is not active.");
        }

        if (request.NetWageGold < 0 ||
            request.TaxGold < 0 ||
            checked(request.NetWageGold + request.TaxGold) != job.WageGold)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.BadRequest("Net wage plus tax must equal the posted wage.");
        }

        var todayCount = await ReadTodayCompanyWorkCountAsync(
            connection,
            transaction,
            normalizedJobId,
            normalizedActorId,
            workDate);
        if (todayCount >= job.DailyLimit)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.Conflict("You have reached this job's daily work limit.");
        }

        var walletGold = await ReadCompanyWalletGoldForUpdateAsync(connection, transaction, normalizedCompanyId);
        if (walletGold is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.NotFound("Company was not found.");
        }

        if (walletGold.Value < job.WageGold)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.Conflict(
                $"Company wallet needs {job.WageGold} gold but only has {walletGold.Value}.");
        }

        var productivityBonusPercent = await ReadCompanyProductivityBonusPercentAsync(
            connection,
            transaction,
            normalizedCompanyId,
            "Productivity");
        var productivityReward = ApplyProductivityBonus(job.ProductivityReward, productivityBonusPercent);
        var workId = $"work-{Guid.NewGuid():N}";
        await using (var debit = new NpgsqlCommand("""
            UPDATE production.companies
            SET wallet_gold = wallet_gold - @wage_gold,
                updated_at = @updated_at
            WHERE company_id = @company_id;
            """, connection, transaction))
        {
            debit.Parameters.AddWithValue("company_id", normalizedCompanyId);
            debit.Parameters.AddWithValue("wage_gold", job.WageGold);
            debit.Parameters.AddWithValue("updated_at", now);
            await debit.ExecuteNonQueryAsync();
        }

        var storageError = await GrantCompanyInventoryAsync(
            connection,
            transaction,
            normalizedCompanyId,
            LaborCreditItemId,
            "Labor Credit",
            "Productivity",
            productivityReward,
            $"Workforce output from {job.Title}.",
            now);
        if (storageError is not null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.Conflict(storageError);
        }

        await using (var insert = new NpgsqlCommand("""
            INSERT INTO production.company_work_records (
                work_id, job_id, company_id, player_id, idempotency_key,
                gross_wage_gold, net_wage_gold, tax_gold, required_energy,
                productivity_reward, status, work_date, worked_at, created_at, updated_at
            )
            VALUES (
                @work_id, @job_id, @company_id, @player_id, @idempotency_key,
                @gross_wage_gold, @net_wage_gold, @tax_gold, @required_energy,
                @productivity_reward, 'pending_credit', @work_date, @worked_at, @created_at, @updated_at
            );
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("work_id", workId);
            insert.Parameters.AddWithValue("job_id", normalizedJobId);
            insert.Parameters.AddWithValue("company_id", normalizedCompanyId);
            insert.Parameters.AddWithValue("player_id", normalizedActorId);
            insert.Parameters.AddWithValue("idempotency_key", idempotencyKey);
            insert.Parameters.AddWithValue("gross_wage_gold", job.WageGold);
            insert.Parameters.AddWithValue("net_wage_gold", request.NetWageGold);
            insert.Parameters.AddWithValue("tax_gold", request.TaxGold);
            insert.Parameters.AddWithValue("required_energy", job.RequiredEnergy);
            insert.Parameters.AddWithValue("productivity_reward", productivityReward);
            insert.Parameters.AddWithValue("work_date", workDate);
            insert.Parameters.AddWithValue("worked_at", now);
            insert.Parameters.AddWithValue("created_at", now);
            insert.Parameters.AddWithValue("updated_at", now);
            await insert.ExecuteNonQueryAsync();
        }

        var workRecord = await ReadCompanyWorkRecordForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            workId);
        var updatedJob = await ReadCompanyJobPostingAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        var assets = await ReadCompanyAssetsAsync(
            connection,
            transaction,
            normalizedCompanyId,
            now,
            normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyWorkResult>.Ok(new CompanyWorkResult(
            Completed: true,
            Message: productivityBonusPercent > 0
                ? $"Work logged for {job.Title}. Company paid {job.WageGold} gold and received {productivityReward} labor credit (+{productivityBonusPercent}% productivity)."
                : $"Work logged for {job.Title}. Company paid {job.WageGold} gold and received {productivityReward} labor credit.",
            Job: updatedJob!,
            WorkRecord: workRecord!,
            Assets: assets));
    }

    public async Task<StoreResult<CompanyWorkResult>> CompleteCompanyWorkAsync(
        string companyId,
        string jobId,
        string workId,
        CompanyWorkCompletionRequest request)
    {
        var normalizedCompanyId = NormalizeId(companyId);
        var normalizedJobId = NormalizeId(jobId);
        var normalizedWorkId = NormalizeId(workId);
        var normalizedActorId = NormalizePlayerId(request.ActorPlayerId);
        if (string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return StoreResult<CompanyWorkResult>.BadRequest("Actor player id is required.");
        }

        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var now = DateTimeOffset.UtcNow;

        var work = await ReadCompanyWorkRecordForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedWorkId);
        if (work is null)
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.NotFound("Company work record was not found.");
        }

        if (!string.Equals(work.PlayerId, normalizedActorId, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync();
            return StoreResult<CompanyWorkResult>.Forbidden("Only the worker can complete this work record.");
        }

        if (work.Status == "pending_credit")
        {
            await using var update = new NpgsqlCommand("""
                UPDATE production.company_work_records
                SET status = 'paid',
                    paid_at = COALESCE(paid_at, @paid_at),
                    updated_at = @updated_at
                WHERE work_id = @work_id;
                """, connection, transaction);
            update.Parameters.AddWithValue("work_id", normalizedWorkId);
            update.Parameters.AddWithValue("paid_at", now);
            update.Parameters.AddWithValue("updated_at", now);
            await update.ExecuteNonQueryAsync();
        }

        var updatedWork = await ReadCompanyWorkRecordForUpdateAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedWorkId);
        var job = await ReadCompanyJobPostingAsync(
            connection,
            transaction,
            normalizedCompanyId,
            normalizedJobId,
            normalizedActorId);
        var assets = await ReadCompanyAssetsAsync(
            connection,
            transaction,
            normalizedCompanyId,
            now,
            normalizedActorId);
        await transaction.CommitAsync();

        return StoreResult<CompanyWorkResult>.Ok(new CompanyWorkResult(
            Completed: true,
            Message: updatedWork!.Status == "paid"
                ? $"Paid {updatedWork.NetWageGold} gold net wage for {job!.Title}."
                : $"Work record is {updatedWork.Status}.",
            Job: job!,
            WorkRecord: updatedWork,
            Assets: assets));
    }

    private static string? ValidateCompanyJobPostingRequest(CompanyJobPostingRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ActorPlayerId))
        {
            return "Actor player id is required.";
        }

        if (NormalizeCompanyJobTitle(request.Title) is null)
        {
            return "Job title must be between 3 and 80 characters.";
        }

        if (request.WageGold is <= 0 or > MaximumJobWageGold)
        {
            return $"Wage must be between 1 and {MaximumJobWageGold} gold.";
        }

        if (request.RequiredEnergy is < 0 or > MaximumJobRequiredEnergy)
        {
            return $"Required energy must be between 0 and {MaximumJobRequiredEnergy}.";
        }

        if (request.DailyLimit is <= 0 or > MaximumJobDailyLimit)
        {
            return $"Daily limit must be between 1 and {MaximumJobDailyLimit}.";
        }

        if (request.ProductivityReward is <= 0 or > MaximumJobProductivityReward)
        {
            return $"Productivity reward must be between 1 and {MaximumJobProductivityReward}.";
        }

        return null;
    }

    private static void AddCompanyJobPostingParameters(
        NpgsqlCommand command,
        string jobId,
        string companyId,
        string actorPlayerId,
        CompanyJobPostingRequest request,
        string status,
        DateTimeOffset now)
    {
        command.Parameters.AddWithValue("job_id", jobId);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("title", NormalizeCompanyJobTitle(request.Title)!);
        command.Parameters.AddWithValue("description", NormalizeCompanyJobDescription(request.Description));
        command.Parameters.AddWithValue("wage_gold", request.WageGold);
        command.Parameters.AddWithValue("required_energy", request.RequiredEnergy);
        command.Parameters.AddWithValue("daily_limit", request.DailyLimit);
        command.Parameters.AddWithValue("productivity_reward", request.ProductivityReward);
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("created_by_player_id", actorPlayerId);
        command.Parameters.AddWithValue("created_at", now);
        command.Parameters.AddWithValue("updated_at", now);
    }

    private static async Task<List<CompanyJobPostingDto>> ReadAllActiveCompanyJobPostingsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string actorPlayerId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT jobs.job_id, jobs.company_id, companies.name AS company_name,
                   jobs.title, jobs.description, jobs.wage_gold, jobs.required_energy,
                   jobs.daily_limit, jobs.productivity_reward, jobs.status,
                   jobs.created_by_player_id, jobs.created_at, jobs.updated_at, jobs.closed_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_work_records records
                       WHERE records.job_id = jobs.job_id
                         AND records.status <> 'cancelled'
                   )::integer AS work_count,
                   (
                       SELECT COUNT(*)
                       FROM production.company_work_records records
                       WHERE records.job_id = jobs.job_id
                         AND records.player_id = @actor_player_id
                         AND records.work_date = @work_date
                         AND records.status <> 'cancelled'
                   )::integer AS today_work_count
            FROM production.company_job_postings jobs
            JOIN production.companies companies ON companies.company_id = jobs.company_id
            WHERE jobs.status = 'active'
            ORDER BY jobs.updated_at DESC, jobs.title;
            """, connection, transaction);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);
        command.Parameters.AddWithValue("work_date", DateOnly.FromDateTime(DateTimeOffset.UtcNow.UtcDateTime));

        var jobs = new List<CompanyJobPostingDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            jobs.Add(ReadCompanyJobPosting(reader));
        }

        return jobs;
    }

    private static async Task<List<CompanyJobPostingDto>> ReadCompanyJobPostingsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string? actorPlayerId,
        bool includeInactive)
    {
        var visibilityFilter = includeInactive ? string.Empty : "AND jobs.status = 'active'";
        await using var command = new NpgsqlCommand($"""
            SELECT jobs.job_id, jobs.company_id, companies.name AS company_name,
                   jobs.title, jobs.description, jobs.wage_gold, jobs.required_energy,
                   jobs.daily_limit, jobs.productivity_reward, jobs.status,
                   jobs.created_by_player_id, jobs.created_at, jobs.updated_at, jobs.closed_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_work_records records
                       WHERE records.job_id = jobs.job_id
                         AND records.status <> 'cancelled'
                   )::integer AS work_count,
                   (
                       SELECT COUNT(*)
                       FROM production.company_work_records records
                       WHERE records.job_id = jobs.job_id
                         AND records.player_id = @actor_player_id
                         AND records.work_date = @work_date
                         AND records.status <> 'cancelled'
                   )::integer AS today_work_count
            FROM production.company_job_postings jobs
            JOIN production.companies companies ON companies.company_id = jobs.company_id
            WHERE jobs.company_id = @company_id
              {visibilityFilter}
            ORDER BY CASE jobs.status WHEN 'active' THEN 0 WHEN 'inactive' THEN 1 ELSE 2 END,
                     jobs.updated_at DESC,
                     jobs.title;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId ?? string.Empty);
        command.Parameters.AddWithValue("work_date", DateOnly.FromDateTime(DateTimeOffset.UtcNow.UtcDateTime));

        var jobs = new List<CompanyJobPostingDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            jobs.Add(ReadCompanyJobPosting(reader));
        }

        return jobs;
    }

    private static async Task<CompanyJobPostingDto?> ReadCompanyJobPostingAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string jobId,
        string actorPlayerId)
    {
        return await ReadCompanyJobPostingByIdAsync(
            connection,
            transaction,
            companyId,
            jobId,
            actorPlayerId,
            forUpdate: false);
    }

    private static async Task<CompanyJobPostingDto?> ReadCompanyJobPostingForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string jobId,
        string actorPlayerId)
    {
        return await ReadCompanyJobPostingByIdAsync(
            connection,
            transaction,
            companyId,
            jobId,
            actorPlayerId,
            forUpdate: true);
    }

    private static async Task<CompanyJobPostingDto?> ReadCompanyJobPostingByIdAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        string jobId,
        string actorPlayerId,
        bool forUpdate)
    {
        var sql = """
            SELECT jobs.job_id, jobs.company_id, companies.name AS company_name,
                   jobs.title, jobs.description, jobs.wage_gold, jobs.required_energy,
                   jobs.daily_limit, jobs.productivity_reward, jobs.status,
                   jobs.created_by_player_id, jobs.created_at, jobs.updated_at, jobs.closed_at,
                   (
                       SELECT COUNT(*)
                       FROM production.company_work_records records
                       WHERE records.job_id = jobs.job_id
                         AND records.status <> 'cancelled'
                   )::integer AS work_count,
                   (
                       SELECT COUNT(*)
                       FROM production.company_work_records records
                       WHERE records.job_id = jobs.job_id
                         AND records.player_id = @actor_player_id
                         AND records.work_date = @work_date
                         AND records.status <> 'cancelled'
                   )::integer AS today_work_count
            FROM production.company_job_postings jobs
            JOIN production.companies companies ON companies.company_id = jobs.company_id
            WHERE jobs.company_id = @company_id AND jobs.job_id = @job_id
            """;
        if (forUpdate)
        {
            sql += " FOR UPDATE OF jobs";
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("job_id", jobId);
        command.Parameters.AddWithValue("actor_player_id", actorPlayerId);
        command.Parameters.AddWithValue("work_date", DateOnly.FromDateTime(DateTimeOffset.UtcNow.UtcDateTime));

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCompanyJobPosting(reader) : null;
    }

    private static CompanyJobPostingDto ReadCompanyJobPosting(NpgsqlDataReader reader)
    {
        var status = reader.GetString(9);
        return new CompanyJobPostingDto(
            JobId: reader.GetString(0),
            CompanyId: reader.GetString(1),
            CompanyName: reader.GetString(2),
            Title: reader.GetString(3),
            Description: reader.GetString(4),
            WageGold: reader.GetInt32(5),
            RequiredEnergy: reader.GetInt32(6),
            DailyLimit: reader.GetInt32(7),
            ProductivityReward: reader.GetInt32(8),
            Status: status,
            IsActive: string.Equals(status, "active", StringComparison.OrdinalIgnoreCase),
            CreatedByPlayerId: reader.GetString(10),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(11),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(12),
            ClosedAt: reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13),
            WorkCount: reader.GetInt32(14),
            TodayWorkCount: reader.GetInt32(15));
    }

    private static async Task<List<CompanyWorkRecordDto>> ReadCompanyWorkRecordsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string companyId,
        int limit)
    {
        await using var command = new NpgsqlCommand("""
            SELECT work_id, job_id, company_id, player_id, idempotency_key,
                   gross_wage_gold, net_wage_gold, tax_gold, required_energy,
                   productivity_reward, status, work_date, worked_at, paid_at,
                   created_at, updated_at
            FROM production.company_work_records
            WHERE company_id = @company_id
              AND status <> 'cancelled'
            ORDER BY worked_at DESC
            LIMIT @limit;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("limit", Math.Clamp(limit, 1, 100));

        var records = new List<CompanyWorkRecordDto>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            records.Add(ReadCompanyWorkRecord(reader));
        }

        return records;
    }

    private static async Task<CompanyWorkRecordDto?> ReadCompanyWorkRecordForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId,
        string jobId,
        string workId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT work_id, job_id, company_id, player_id, idempotency_key,
                   gross_wage_gold, net_wage_gold, tax_gold, required_energy,
                   productivity_reward, status, work_date, worked_at, paid_at,
                   created_at, updated_at
            FROM production.company_work_records
            WHERE company_id = @company_id AND job_id = @job_id AND work_id = @work_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        command.Parameters.AddWithValue("job_id", jobId);
        command.Parameters.AddWithValue("work_id", workId);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCompanyWorkRecord(reader) : null;
    }

    private static async Task<CompanyWorkRecordDto?> ReadCompanyWorkRecordByIdempotencyForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string idempotencyKey)
    {
        await using var command = new NpgsqlCommand("""
            SELECT work_id, job_id, company_id, player_id, idempotency_key,
                   gross_wage_gold, net_wage_gold, tax_gold, required_energy,
                   productivity_reward, status, work_date, worked_at, paid_at,
                   created_at, updated_at
            FROM production.company_work_records
            WHERE idempotency_key = @idempotency_key
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("idempotency_key", idempotencyKey);

        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadCompanyWorkRecord(reader) : null;
    }

    private static CompanyWorkRecordDto ReadCompanyWorkRecord(NpgsqlDataReader reader)
    {
        return new CompanyWorkRecordDto(
            WorkId: reader.GetString(0),
            JobId: reader.GetString(1),
            CompanyId: reader.GetString(2),
            PlayerId: reader.GetString(3),
            IdempotencyKey: reader.GetString(4),
            GrossWageGold: reader.GetInt32(5),
            NetWageGold: reader.GetInt32(6),
            TaxGold: reader.GetInt32(7),
            RequiredEnergy: reader.GetInt32(8),
            ProductivityReward: reader.GetInt32(9),
            Status: reader.GetString(10),
            WorkDate: reader.GetFieldValue<DateOnly>(11),
            WorkedAt: reader.GetFieldValue<DateTimeOffset>(12),
            PaidAt: reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13),
            CreatedAt: reader.GetFieldValue<DateTimeOffset>(14),
            UpdatedAt: reader.GetFieldValue<DateTimeOffset>(15));
    }

    private static async Task<int?> ReadCompanyWalletGoldForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string companyId)
    {
        await using var command = new NpgsqlCommand("""
            SELECT wallet_gold
            FROM production.companies
            WHERE company_id = @company_id
            FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("company_id", companyId);
        var result = await command.ExecuteScalarAsync();
        return result is int walletGold ? walletGold : null;
    }

    private static async Task<int> ReadTodayCompanyWorkCountAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string jobId,
        string playerId,
        DateOnly workDate)
    {
        await using var command = new NpgsqlCommand("""
            SELECT COUNT(*)
            FROM production.company_work_records
            WHERE job_id = @job_id
              AND player_id = @player_id
              AND work_date = @work_date
              AND status <> 'cancelled';
            """, connection, transaction);
        command.Parameters.AddWithValue("job_id", jobId);
        command.Parameters.AddWithValue("player_id", playerId);
        command.Parameters.AddWithValue("work_date", workDate);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private static string? NormalizeCompanyJobTitle(string? title)
    {
        var normalized = string.Join(
            ' ',
            (title ?? string.Empty)
                .Trim()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return normalized.Length is < 3 or > 80 ? null : normalized;
    }

    private static string NormalizeCompanyJobDescription(string? description)
    {
        var normalized = string.Join(
            ' ',
            (description ?? string.Empty)
                .Trim()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries));
        if (normalized.Length > 240)
        {
            normalized = normalized[..240];
        }

        return string.IsNullOrWhiteSpace(normalized)
            ? "A paid company work shift."
            : normalized;
    }

    private static string? NormalizeIdempotencyKey(string? value)
    {
        var normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
        return string.IsNullOrWhiteSpace(normalized) || normalized.Length > 160
            ? null
            : normalized;
    }
}

internal sealed record CompanyJobPostingRequest(
    string? ActorPlayerId,
    string? Title,
    string? Description,
    int WageGold,
    int RequiredEnergy,
    int DailyLimit,
    int ProductivityReward,
    bool? IsActive);

internal sealed record CompanyWorkRequest(
    string? ActorPlayerId,
    string? IdempotencyKey,
    int NetWageGold,
    int TaxGold);

internal sealed record CompanyWorkCompletionRequest(
    string? ActorPlayerId,
    string? IdempotencyKey);

internal sealed record CompanyJobListResponse(
    string? CompanyId,
    CompanyJobPostingDto[] Jobs,
    DateTimeOffset UpdatedAt);

internal sealed record CompanyJobMutationResponse(
    bool Completed,
    string Message,
    CompanyJobPostingDto? Job,
    CompanyAssetsDto? Assets);

internal sealed record CompanyJobPostingDto(
    string JobId,
    string CompanyId,
    string CompanyName,
    string Title,
    string Description,
    int WageGold,
    int RequiredEnergy,
    int DailyLimit,
    int ProductivityReward,
    string Status,
    bool IsActive,
    string CreatedByPlayerId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ClosedAt,
    int WorkCount,
    int TodayWorkCount);

internal sealed record CompanyWorkResult(
    bool Completed,
    string Message,
    CompanyJobPostingDto Job,
    CompanyWorkRecordDto WorkRecord,
    CompanyAssetsDto? Assets);

internal sealed record CompanyWorkRecordDto(
    string WorkId,
    string JobId,
    string CompanyId,
    string PlayerId,
    string IdempotencyKey,
    int GrossWageGold,
    int NetWageGold,
    int TaxGold,
    int RequiredEnergy,
    int ProductivityReward,
    string Status,
    DateOnly WorkDate,
    DateTimeOffset WorkedAt,
    DateTimeOffset? PaidAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
