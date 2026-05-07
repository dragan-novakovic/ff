internal static class AdvancedMarketGatewayEndpoints
{
    public static void MapAdvancedMarketGatewayEndpoints(this WebApplication app)
    {
        app.MapGet("/market/price-history", async (
            string? itemId,
            int? limit,
            HttpRequest request,
            MarketServiceClient market,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var query = BuildQuery(
                ("itemId", itemId),
                ("limit", Math.Clamp(limit ?? 50, 1, 200).ToString()));
            return await market.GetAsync($"market/price-history{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMarketPriceHistory");

        app.MapGet("/market/order-book", async (
            string? itemId,
            HttpRequest request,
            MarketServiceClient market,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var query = BuildQuery(("itemId", itemId));
            return await market.GetAsync($"market/order-book{query}", request.Headers.Authorization.ToString());
        }).WithName("GetGatewayMarketOrderBook");

        app.MapGet("/trade/offers", async (
            string? actorType,
            string? actorId,
            string? status,
            HttpRequest request,
            MarketServiceClient market,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var actorValidation = await ValidateTradeOfferListAccessAsync(
                actorType,
                actorId,
                access.PlayerId!,
                request.Headers.Authorization.ToString(),
                production);
            if (actorValidation is not null)
            {
                return actorValidation;
            }

            var query = BuildQuery(
                ("actorType", actorType),
                ("actorId", actorId),
                ("status", status));
            return await market.GetAsync($"trade/offers{query}", request.Headers.Authorization.ToString());
        }).WithName("ListGatewayTradeOffers");

        app.MapGet("/companies/{companyId}/trade/offers", async (
            string companyId,
            string? status,
            HttpRequest request,
            MarketServiceClient market,
            ProductionServiceClient production,
            DevTokenValidator tokens) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var company = await GetCompanyAssetsAsync(production, companyId, access.PlayerId!, request.Headers.Authorization.ToString());
            if (company.Error is not null)
            {
                return company.Error;
            }

            var query = BuildQuery(
                ("actorType", TradeActorKinds.Company),
                ("actorId", companyId),
                ("status", status));
            return await market.GetAsync($"trade/offers{query}", request.Headers.Authorization.ToString());
        }).WithName("ListGatewayCompanyTradeOffers");

        app.MapPost("/players/{playerId}/trade/offers", async (
            string playerId,
            TradeOfferGatewayRequest offerRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            MarketServiceClient market,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
            await CreateTradeOfferAsync(
                playerId,
                TradeActorKinds.Player,
                playerId,
                offerRequest,
                request,
                economy,
                production,
                market,
                world,
                notifications,
                configuration,
                tokens,
                antiAbuse))
            .WithName("CreateGatewayPlayerTradeOffer");

        app.MapPost("/companies/{companyId}/trade/offers", async (
            string companyId,
            TradeOfferGatewayRequest offerRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            MarketServiceClient market,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var company = await GetCompanyAssetsAsync(production, companyId, access.PlayerId!, request.Headers.Authorization.ToString());
            if (company.Error is not null)
            {
                return company.Error;
            }

            return await CreateTradeOfferForActorAsync(
                access.PlayerId!,
                TradeActorKinds.Company,
                company.Value!.CompanyId,
                offerRequest,
                request,
                economy,
                production,
                market,
                world,
                notifications,
                configuration,
                antiAbuse);
        }).WithName("CreateGatewayCompanyTradeOffer");

        app.MapPost("/players/{playerId}/trade/offers/{offerId}/accept", async (
            string playerId,
            string offerId,
            TradeOfferActionRequest actionRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            MarketServiceClient market,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
            await AcceptTradeOfferAsync(
                playerId,
                null,
                offerId,
                actionRequest,
                request,
                economy,
                production,
                market,
                world,
                notifications,
                configuration,
                tokens,
                antiAbuse))
            .WithName("AcceptGatewayPlayerTradeOffer");

        app.MapPost("/companies/{companyId}/trade/offers/{offerId}/accept", async (
            string companyId,
            string offerId,
            TradeOfferActionRequest actionRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            MarketServiceClient market,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var company = await GetCompanyAssetsAsync(production, companyId, access.PlayerId!, request.Headers.Authorization.ToString());
            if (company.Error is not null)
            {
                return company.Error;
            }

            return await AcceptTradeOfferForActorAsync(
                access.PlayerId!,
                company.Value!.CompanyId,
                offerId,
                actionRequest,
                request,
                economy,
                production,
                market,
                world,
                notifications,
                configuration,
                antiAbuse);
        }).WithName("AcceptGatewayCompanyTradeOffer");

        app.MapPost("/players/{playerId}/trade/offers/{offerId}/cancel", async (
            string playerId,
            string offerId,
            TradeOfferActionRequest actionRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            MarketServiceClient market,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
            await CancelTradeOfferAsync(
                playerId,
                null,
                offerId,
                actionRequest,
                request,
                economy,
                production,
                market,
                world,
                notifications,
                configuration,
                tokens,
                antiAbuse))
            .WithName("CancelGatewayPlayerTradeOffer");

        app.MapPost("/companies/{companyId}/trade/offers/{offerId}/cancel", async (
            string companyId,
            string offerId,
            TradeOfferActionRequest actionRequest,
            HttpRequest request,
            EconomyServiceClient economy,
            ProductionServiceClient production,
            MarketServiceClient market,
            WorldServiceClient world,
            NotificationServiceClient notifications,
            IConfiguration configuration,
            DevTokenValidator tokens,
            AntiAbuseStore antiAbuse) =>
        {
            var access = ValidateBearerPlayer(request, tokens);
            if (access.Error is not null)
            {
                return access.Error;
            }

            var company = await GetCompanyAssetsAsync(production, companyId, access.PlayerId!, request.Headers.Authorization.ToString());
            if (company.Error is not null)
            {
                return company.Error;
            }

            return await CancelTradeOfferForActorAsync(
                access.PlayerId!,
                company.Value!.CompanyId,
                offerId,
                actionRequest,
                request,
                economy,
                production,
                market,
                world,
                notifications,
                configuration,
                antiAbuse);
        }).WithName("CancelGatewayCompanyTradeOffer");
    }

    private static async Task<IResult> CreateTradeOfferAsync(
        string playerId,
        string defaultSellerType,
        string defaultSellerId,
        TradeOfferGatewayRequest offerRequest,
        HttpRequest request,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        MarketServiceClient market,
        WorldServiceClient world,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        DevTokenValidator tokens,
        AntiAbuseStore antiAbuse)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        return await CreateTradeOfferForActorAsync(
            access.PlayerId!,
            defaultSellerType,
            defaultSellerId,
            offerRequest,
            request,
            economy,
            production,
            market,
            world,
            notifications,
            configuration,
            antiAbuse);
    }

    private static async Task<IResult> CreateTradeOfferForActorAsync(
        string actorPlayerId,
        string defaultSellerType,
        string defaultSellerId,
        TradeOfferGatewayRequest offerRequest,
        HttpRequest request,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        MarketServiceClient market,
        WorldServiceClient world,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        AntiAbuseStore antiAbuse)
    {
        var authorization = request.Headers.Authorization.ToString();
        var sellerType = NormalizeActorType(offerRequest.SellerType, defaultSellerType);
        var sellerId = NormalizeIdOrDefault(offerRequest.SellerId, defaultSellerId);
        var buyerType = NormalizeActorType(offerRequest.BuyerType, string.Empty);
        var buyerId = NormalizeIdOrDefault(offerRequest.BuyerId, string.Empty);
        var itemId = NormalizeIdOrDefault(offerRequest.ItemId, string.Empty);
        if (sellerType is null ||
            buyerType is null ||
            string.IsNullOrWhiteSpace(sellerId) ||
            string.IsNullOrWhiteSpace(buyerId) ||
            string.IsNullOrWhiteSpace(itemId) ||
            offerRequest.Quantity <= 0 ||
            offerRequest.PricePerUnit <= 0)
        {
            return Results.BadRequest(new ErrorResponse("Seller, buyer, item, quantity, and price are required."));
        }

        if (sellerType == TradeActorKinds.Player &&
            !string.Equals(sellerId, actorPlayerId, StringComparison.OrdinalIgnoreCase))
        {
            return Results.Json(
                new ErrorResponse("You can only create player trade offers from your own inventory."),
                statusCode: StatusCodes.Status403Forbidden);
        }

        if (sellerType == TradeActorKinds.Company)
        {
            var company = await GetCompanyAssetsAsync(production, sellerId, actorPlayerId, authorization);
            if (company.Error is not null)
            {
                return company.Error;
            }
        }

        var sellerItem = await GetActorItemAsync(
            sellerType,
            sellerId,
            actorPlayerId,
            itemId,
            authorization,
            economy,
            production);
        if (sellerItem.Error is not null)
        {
            return sellerItem.Error;
        }

        var item = sellerItem.Value!;
        if (item.Quantity < offerRequest.Quantity)
        {
            return Results.Json(
                new ErrorResponse($"Not enough {item.Name}. Required {offerRequest.Quantity}, available {item.Quantity}."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var diplomacyError = await ValidateTradeDiplomacyAsync(
            world,
            sellerType,
            sellerId,
            buyerType,
            buyerId,
            sellerType == TradeActorKinds.Player ? sellerId : actorPlayerId,
            buyerType == TradeActorKinds.Player ? buyerId : null,
            authorization,
            configuration);
        if (diplomacyError is not null)
        {
            return diplomacyError;
        }

        var offerId = string.IsNullOrWhiteSpace(offerRequest.OfferId)
            ? $"offer-{Guid.NewGuid():N}"
            : NormalizeIdOrDefault(offerRequest.OfferId, string.Empty);
        var idempotencyKey = string.IsNullOrWhiteSpace(offerRequest.IdempotencyKey)
            ? $"trade-offer:{offerId}"
            : NormalizeIdOrDefault(offerRequest.IdempotencyKey, $"trade-offer:{offerId}");
        var antiAbuseDecision = await antiAbuse.EnforceAsync(
            AntiAbuseRules.TradeCreate,
            new AntiAbuseCheck(
                actorPlayerId,
                sellerType == TradeActorKinds.Company
                    ? "/companies/{companyId}/trade/offers"
                    : "/players/{playerId}/trade/offers",
                "trade_offer",
                offerId,
                offerRequest.IdempotencyKey,
                new
                {
                    SellerType = sellerType,
                    SellerId = sellerId,
                    BuyerType = buyerType,
                    BuyerId = buyerId,
                    ItemId = item.ItemId,
                    offerRequest.Quantity,
                    offerRequest.PricePerUnit
                }));
        if (antiAbuseDecision.Error is not null)
        {
            return antiAbuseDecision.Error;
        }

        var reserve = await RemoveActorItemAsync(
            sellerType,
            sellerId,
            actorPlayerId,
            item,
            offerRequest.Quantity,
            $"Reserved {offerRequest.Quantity} {item.Name} for trade offer {offerId}.",
            $"trade-offer-reserve:{offerId}",
            authorization,
            economy,
            production,
            configuration);
        if (reserve.Error is not null)
        {
            return reserve.Error;
        }

        if (!reserve.Value!.Completed)
        {
            return Results.Json(new ErrorResponse(reserve.Value.Message), statusCode: StatusCodes.Status409Conflict);
        }

        var created = await market.PostJsonAsync<CreateTradeOfferRequestDto, TradeOfferMutationResponseDto>(
            "trade/offers",
            authorization,
            new CreateTradeOfferRequestDto(
                OfferId: offerId,
                CreatorPlayerId: actorPlayerId,
                SellerType: sellerType,
                SellerId: sellerId,
                BuyerType: buyerType,
                BuyerId: buyerId,
                ItemId: item.ItemId,
                ItemName: item.Name,
                Category: item.Category,
                Quantity: offerRequest.Quantity,
                PricePerUnit: offerRequest.PricePerUnit,
                IdempotencyKey: idempotencyKey,
                ExpiresAt: null),
            InternalToken(configuration));
        if (created.Error is not null)
        {
            return created.Error;
        }

        var response = created.Value!;
        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            actorPlayerId,
            "trade_offer_created",
            $"Created trade offer {response.Offer?.OfferId ?? offerId} for {offerRequest.Quantity} {item.Name}.",
            response.Offer?.OfferId ?? offerId,
            $"activity:trade-offer-created:{actorPlayerId}:{offerId}");
        return Results.Ok(new TradeOfferGatewayResponse(
            Completed: response.Completed,
            Message: response.Message,
            Offer: response.Offer,
            Contract: response.Contract,
            TotalPrice: offerRequest.Quantity * offerRequest.PricePerUnit));
    }

    private static async Task<IResult> AcceptTradeOfferAsync(
        string playerId,
        string? requiredBuyerCompanyId,
        string offerId,
        TradeOfferActionRequest actionRequest,
        HttpRequest request,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        MarketServiceClient market,
        WorldServiceClient world,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        DevTokenValidator tokens,
        AntiAbuseStore antiAbuse)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        return await AcceptTradeOfferForActorAsync(
            access.PlayerId!,
            requiredBuyerCompanyId,
            offerId,
            actionRequest,
            request,
            economy,
            production,
            market,
            world,
            notifications,
            configuration,
            antiAbuse);
    }

    private static async Task<IResult> AcceptTradeOfferForActorAsync(
        string actorPlayerId,
        string? requiredBuyerCompanyId,
        string offerId,
        TradeOfferActionRequest actionRequest,
        HttpRequest request,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        MarketServiceClient market,
        WorldServiceClient world,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        AntiAbuseStore antiAbuse)
    {
        var authorization = request.Headers.Authorization.ToString();
        var offerResult = await market.GetJsonAsync<TradeOfferDto>(
            $"trade/offers/{Uri.EscapeDataString(offerId)}",
            authorization);
        if (offerResult.Error is not null)
        {
            return offerResult.Error;
        }

        var offer = offerResult.Value!;
        if (requiredBuyerCompanyId is not null &&
            (!string.Equals(offer.BuyerType, TradeActorKinds.Company, StringComparison.OrdinalIgnoreCase) ||
             !string.Equals(offer.BuyerId, requiredBuyerCompanyId, StringComparison.OrdinalIgnoreCase)))
        {
            return Results.Json(
                new ErrorResponse("This trade offer is not addressed to that company."),
                statusCode: StatusCodes.Status403Forbidden);
        }

        var buyerAccess = await ValidateBuyerAccessAsync(offer, actorPlayerId, authorization, production);
        if (buyerAccess is not null)
        {
            return buyerAccess;
        }

        var diplomacyError = await ValidateTradeDiplomacyAsync(
            world,
            offer.SellerType,
            offer.SellerId,
            offer.BuyerType,
            offer.BuyerId,
            offer.SellerType == TradeActorKinds.Player ? offer.SellerId : offer.CreatorPlayerId,
            actorPlayerId,
            authorization,
            configuration);
        if (diplomacyError is not null)
        {
            return diplomacyError;
        }

        var totalPrice = checked(offer.Quantity * offer.PricePerUnit);
        var buyerWallet = await GetActorWalletGoldAsync(
            offer.BuyerType,
            offer.BuyerId,
            actorPlayerId,
            authorization,
            economy,
            production);
        if (buyerWallet.Error is not null)
        {
            return buyerWallet.Error;
        }

        if (buyerWallet.Value < totalPrice)
        {
            return Results.Json(
                new ErrorResponse($"Not enough buyer gold. Required {totalPrice}, available {buyerWallet.Value}."),
                statusCode: StatusCodes.Status409Conflict);
        }

        var antiAbuseDecision = await antiAbuse.EnforceAsync(
            AntiAbuseRules.TradeAccept,
            new AntiAbuseCheck(
                actorPlayerId,
                requiredBuyerCompanyId is null
                    ? "/players/{playerId}/trade/offers/{offerId}/accept"
                    : "/companies/{companyId}/trade/offers/{offerId}/accept",
                "trade_offer",
                offer.OfferId,
                actionRequest.IdempotencyKey,
                new
                {
                    offer.SellerType,
                    offer.SellerId,
                    offer.BuyerType,
                    offer.BuyerId,
                    offer.ItemId,
                    offer.Quantity,
                    offer.PricePerUnit,
                    TotalPrice = totalPrice
                }));
        if (antiAbuseDecision.Error is not null)
        {
            return antiAbuseDecision.Error;
        }

        var acceptKey = NormalizeIdOrDefault(actionRequest.IdempotencyKey, $"trade-accept:{offer.OfferId}:{actorPlayerId}");
        var accepted = await market.PostJsonAsync<AcceptTradeOfferRequestDto, TradeOfferMutationResponseDto>(
            $"trade/offers/{Uri.EscapeDataString(offer.OfferId)}/accept",
            authorization,
            new AcceptTradeOfferRequestDto(actorPlayerId, acceptKey),
            InternalToken(configuration));
        if (accepted.Error is not null)
        {
            return accepted.Error;
        }

        var acceptedResponse = accepted.Value!;
        if (!acceptedResponse.Completed || acceptedResponse.Contract is null || acceptedResponse.Offer is null)
        {
            return Results.Json(
                new ErrorResponse(acceptedResponse.Message),
                statusCode: StatusCodes.Status409Conflict);
        }

        offer = acceptedResponse.Offer;
        var contract = acceptedResponse.Contract;
        var debit = await DebitActorGoldAsync(
            offer.BuyerType,
            offer.BuyerId,
            actorPlayerId,
            totalPrice,
            $"Paid {totalPrice} gold for trade contract {contract.ContractId}.",
            $"trade:{contract.ContractId}:buyer-debit",
            authorization,
            economy,
            production,
            configuration);
        if (debit.Error is not null)
        {
            await market.PostJsonAsync<FailTradeContractRequestDto, TradeOfferMutationResponseDto>(
                $"trade/contracts/{Uri.EscapeDataString(contract.ContractId)}/fail",
                authorization,
                new FailTradeContractRequestDto("Buyer payment failed."),
                InternalToken(configuration));
            await RefundSellerReservationAsync(offer, actorPlayerId, contract.ContractId, authorization, economy, production, configuration);
            return debit.Error;
        }

        if (!debit.Value!.Completed)
        {
            await market.PostJsonAsync<FailTradeContractRequestDto, TradeOfferMutationResponseDto>(
                $"trade/contracts/{Uri.EscapeDataString(contract.ContractId)}/fail",
                authorization,
                new FailTradeContractRequestDto(debit.Value.Message),
                InternalToken(configuration));
            await RefundSellerReservationAsync(offer, actorPlayerId, contract.ContractId, authorization, economy, production, configuration);
            return Results.Json(new ErrorResponse(debit.Value.Message), statusCode: StatusCodes.Status409Conflict);
        }

        var sellerCredit = await CreditActorGoldAsync(
            offer.SellerType,
            offer.SellerId,
            offer.SellerType == TradeActorKinds.Company ? offer.CreatorPlayerId : offer.SellerId,
            totalPrice,
            $"Received {totalPrice} gold for trade contract {contract.ContractId}.",
            $"trade:{contract.ContractId}:seller-credit",
            authorization,
            economy,
            production,
            configuration);
        if (sellerCredit.Error is not null)
        {
            return sellerCredit.Error;
        }

        var buyerGrant = await GrantActorItemAsync(
            offer.BuyerType,
            offer.BuyerId,
            actorPlayerId,
            new ActorItemDto(offer.ItemId, offer.ItemName, offer.Category, offer.Quantity, string.Empty),
            offer.Quantity,
            $"Received {offer.Quantity} {offer.ItemName} from trade contract {contract.ContractId}.",
            $"trade:{contract.ContractId}:buyer-item",
            authorization,
            economy,
            production,
            configuration);
        if (buyerGrant.Error is not null)
        {
            return buyerGrant.Error;
        }

        var fulfilled = await market.PostJsonAsync<FulfillTradeContractRequestDto, TradeOfferMutationResponseDto>(
            $"trade/contracts/{Uri.EscapeDataString(contract.ContractId)}/fulfill",
            authorization,
            new FulfillTradeContractRequestDto($"trade:{contract.ContractId}:fulfill"),
            InternalToken(configuration));
        if (fulfilled.Error is not null)
        {
            return fulfilled.Error;
        }

        var fulfilledResponse = fulfilled.Value!;
        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            actorPlayerId,
            "trade_contract_fulfilled",
            $"Fulfilled trade contract {contract.ContractId} for {offer.Quantity} {offer.ItemName}.",
            contract.ContractId,
            $"activity:trade-accepted:{actorPlayerId}:{contract.ContractId}");
        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            offer.CreatorPlayerId,
            "trade_contract_fulfilled",
            $"Trade offer {offer.OfferId} was fulfilled for {totalPrice} gold.",
            contract.ContractId,
            $"activity:trade-fulfilled:{offer.CreatorPlayerId}:{contract.ContractId}");

        return Results.Ok(new TradeOfferGatewayResponse(
            Completed: fulfilledResponse.Completed,
            Message: fulfilledResponse.Message,
            Offer: fulfilledResponse.Offer,
            Contract: fulfilledResponse.Contract,
            TotalPrice: totalPrice));
    }

    private static async Task<IResult> CancelTradeOfferAsync(
        string playerId,
        string? requiredSellerCompanyId,
        string offerId,
        TradeOfferActionRequest actionRequest,
        HttpRequest request,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        MarketServiceClient market,
        WorldServiceClient world,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        DevTokenValidator tokens,
        AntiAbuseStore antiAbuse)
    {
        var access = ValidatePlayerAccess(playerId, request, tokens);
        if (access.Error is not null)
        {
            return access.Error;
        }

        return await CancelTradeOfferForActorAsync(
            access.PlayerId!,
            requiredSellerCompanyId,
            offerId,
            actionRequest,
            request,
            economy,
            production,
            market,
            world,
            notifications,
            configuration,
            antiAbuse);
    }

    private static async Task<IResult> CancelTradeOfferForActorAsync(
        string actorPlayerId,
        string? requiredSellerCompanyId,
        string offerId,
        TradeOfferActionRequest actionRequest,
        HttpRequest request,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        MarketServiceClient market,
        WorldServiceClient world,
        NotificationServiceClient notifications,
        IConfiguration configuration,
        AntiAbuseStore antiAbuse)
    {
        var authorization = request.Headers.Authorization.ToString();
        var offerResult = await market.GetJsonAsync<TradeOfferDto>(
            $"trade/offers/{Uri.EscapeDataString(offerId)}",
            authorization);
        if (offerResult.Error is not null)
        {
            return offerResult.Error;
        }

        var offer = offerResult.Value!;
        if (requiredSellerCompanyId is not null &&
            (!string.Equals(offer.SellerType, TradeActorKinds.Company, StringComparison.OrdinalIgnoreCase) ||
             !string.Equals(offer.SellerId, requiredSellerCompanyId, StringComparison.OrdinalIgnoreCase)))
        {
            return Results.Json(
                new ErrorResponse("This trade offer was not created by that company."),
                statusCode: StatusCodes.Status403Forbidden);
        }

        var cancelAccess = await ValidateCancelAccessAsync(offer, actorPlayerId, authorization, production);
        if (cancelAccess is not null)
        {
            return cancelAccess;
        }

        var antiAbuseDecision = await antiAbuse.EnforceAsync(
            AntiAbuseRules.TradeCancel,
            new AntiAbuseCheck(
                actorPlayerId,
                requiredSellerCompanyId is null
                    ? "/players/{playerId}/trade/offers/{offerId}/cancel"
                    : "/companies/{companyId}/trade/offers/{offerId}/cancel",
                "trade_offer",
                offer.OfferId,
                actionRequest.IdempotencyKey,
                new
                {
                    offer.SellerType,
                    offer.SellerId,
                    offer.BuyerType,
                    offer.BuyerId,
                    offer.ItemId,
                    offer.Quantity,
                    offer.PricePerUnit,
                    actionRequest.Reason
                }));
        if (antiAbuseDecision.Error is not null)
        {
            return antiAbuseDecision.Error;
        }

        var cancelKey = NormalizeIdOrDefault(actionRequest.IdempotencyKey, $"trade-cancel:{offer.OfferId}:{actorPlayerId}");
        var cancelled = await market.PostJsonAsync<CancelTradeOfferRequestDto, TradeOfferMutationResponseDto>(
            $"trade/offers/{Uri.EscapeDataString(offer.OfferId)}/cancel",
            authorization,
            new CancelTradeOfferRequestDto(actorPlayerId, actionRequest.Reason, cancelKey),
            InternalToken(configuration));
        if (cancelled.Error is not null)
        {
            return cancelled.Error;
        }

        var response = cancelled.Value!;
        if (response.Completed && response.Offer is not null)
        {
            var refund = await GrantActorItemAsync(
                response.Offer.SellerType,
                response.Offer.SellerId,
                actorPlayerId,
                new ActorItemDto(
                    response.Offer.ItemId,
                    response.Offer.ItemName,
                    response.Offer.Category,
                    response.Offer.Quantity,
                    string.Empty),
                response.Offer.Quantity,
                $"Returned reserved items from cancelled trade offer {response.Offer.OfferId}.",
                $"trade-offer-cancel:{response.Offer.OfferId}",
                authorization,
                economy,
                production,
                configuration);
            if (refund.Error is not null)
            {
                return refund.Error;
            }
        }

        await ActivityGatewayEndpoints.EmitAsync(
            notifications,
            configuration,
            actorPlayerId,
            "trade_offer_cancelled",
            $"Cancelled trade offer {offer.OfferId}.",
            offer.OfferId,
            $"activity:trade-cancelled:{actorPlayerId}:{offer.OfferId}");

        return Results.Ok(new TradeOfferGatewayResponse(
            Completed: response.Completed,
            Message: response.Message,
            Offer: response.Offer,
            Contract: response.Contract,
            TotalPrice: offer.Quantity * offer.PricePerUnit));
    }

    private static async Task<IResult?> ValidateTradeDiplomacyAsync(
        WorldServiceClient world,
        string sellerType,
        string sellerId,
        string buyerType,
        string buyerId,
        string? sellerPlayerId,
        string? buyerPlayerId,
        string authorization,
        IConfiguration configuration)
    {
        if (string.IsNullOrWhiteSpace(sellerPlayerId) ||
            string.IsNullOrWhiteSpace(buyerPlayerId) ||
            (sellerType == TradeActorKinds.Company && buyerType == TradeActorKinds.Company) ||
            string.Equals(sellerId, buyerId, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var sellerCountry = await ResolveTradeActorCountryAsync(world, sellerPlayerId, configuration);
        if (sellerCountry.Error is not null)
        {
            return sellerCountry.Error;
        }

        var buyerCountry = await ResolveTradeActorCountryAsync(world, buyerPlayerId, configuration);
        if (buyerCountry.Error is not null)
        {
            return buyerCountry.Error;
        }

        if (sellerCountry.Value is null ||
            buyerCountry.Value is null ||
            string.Equals(sellerCountry.Value.CountryId, buyerCountry.Value.CountryId, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relationship = await world.GetJsonAsync<DiplomacyRelationshipCheckDto>(
            $"internal/diplomacy/countries/{Uri.EscapeDataString(sellerCountry.Value.CountryId)}/counterparties/{Uri.EscapeDataString(buyerCountry.Value.CountryId)}",
            string.Empty,
            InternalToken(configuration));
        if (relationship.Error is not null)
        {
            return relationship.Error;
        }

        return relationship.Value!.HasActiveEmbargo
            ? Results.Json(
                new ErrorResponse(
                    $"Trade is blocked by an active embargo between {sellerCountry.Value.CountryName} and {buyerCountry.Value.CountryName}."),
                statusCode: StatusCodes.Status409Conflict)
            : null;
    }

    private static async Task<ServiceJsonResult<PlayerCitizenshipDto?>> ResolveTradeActorCountryAsync(
        WorldServiceClient world,
        string playerId,
        IConfiguration configuration)
    {
        var citizenship = await world.GetJsonAsync<PlayerCitizenshipResponseDto>(
            $"internal/players/{Uri.EscapeDataString(playerId)}/citizenship",
            string.Empty,
            InternalToken(configuration));
        if (citizenship.Error is not null)
        {
            return ServiceJsonResult<PlayerCitizenshipDto?>.Failed(citizenship.Error);
        }

        var country = citizenship.Value!.Citizenship;
        return country is null ||
            !string.Equals(country.Status, "active", StringComparison.OrdinalIgnoreCase)
                ? ServiceJsonResult<PlayerCitizenshipDto?>.Succeeded(null)
                : ServiceJsonResult<PlayerCitizenshipDto?>.Succeeded(country);
    }

    private static async Task<ServiceJsonResult<ActorItemDto>> GetActorItemAsync(
        string actorType,
        string actorId,
        string actorPlayerId,
        string itemId,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production)
    {
        if (actorType == TradeActorKinds.Player)
        {
            var inventory = await economy.GetJsonAsync<InventoryResponseDto>(
                $"players/{Uri.EscapeDataString(actorId)}/inventory",
                authorization);
            if (inventory.Error is not null)
            {
                return ServiceJsonResult<ActorItemDto>.Failed(inventory.Error);
            }

            var item = inventory.Value!.Items.FirstOrDefault(candidate =>
                string.Equals(candidate.ItemId, itemId, StringComparison.OrdinalIgnoreCase));
            return item is null
                ? ServiceJsonResult<ActorItemDto>.Failed(Results.Json(
                    new ErrorResponse("Seller does not have that item."),
                    statusCode: StatusCodes.Status409Conflict))
                : ServiceJsonResult<ActorItemDto>.Succeeded(new ActorItemDto(
                    item.ItemId,
                    item.Name,
                    item.Category,
                    item.Quantity,
                    item.Description));
        }

        var assets = await GetCompanyAssetsAsync(production, actorId, actorPlayerId, authorization);
        if (assets.Error is not null)
        {
            return ServiceJsonResult<ActorItemDto>.Failed(assets.Error);
        }

        var companyItem = assets.Value!.Inventory.FirstOrDefault(candidate =>
            string.Equals(candidate.ItemId, itemId, StringComparison.OrdinalIgnoreCase));
        return companyItem is null
            ? ServiceJsonResult<ActorItemDto>.Failed(Results.Json(
                new ErrorResponse("Company does not have that item."),
                statusCode: StatusCodes.Status409Conflict))
            : ServiceJsonResult<ActorItemDto>.Succeeded(new ActorItemDto(
                companyItem.ItemId,
                companyItem.Name,
                companyItem.Category,
                companyItem.Quantity,
                companyItem.Description));
    }

    private static async Task<ServiceJsonResult<int>> GetActorWalletGoldAsync(
        string actorType,
        string actorId,
        string actorPlayerId,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production)
    {
        if (actorType == TradeActorKinds.Player)
        {
            var inventory = await economy.GetJsonAsync<InventoryResponseDto>(
                $"players/{Uri.EscapeDataString(actorId)}/inventory",
                authorization);
            return inventory.Error is not null
                ? ServiceJsonResult<int>.Failed(inventory.Error)
                : ServiceJsonResult<int>.Succeeded(inventory.Value!.WalletGold);
        }

        var assets = await GetCompanyAssetsAsync(production, actorId, actorPlayerId, authorization);
        return assets.Error is not null
            ? ServiceJsonResult<int>.Failed(assets.Error)
            : ServiceJsonResult<int>.Succeeded(assets.Value!.WalletGold);
    }

    private static async Task<ServiceJsonResult<AssetMutationResultDto>> RemoveActorItemAsync(
        string actorType,
        string actorId,
        string actorPlayerId,
        ActorItemDto item,
        int quantity,
        string reason,
        string idempotencyKey,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        IConfiguration configuration)
    {
        if (actorType == TradeActorKinds.Player)
        {
            var result = await economy.PostJsonAsync<InventoryRemovalRequestDto, InventoryMutationResponseDto>(
                $"players/{Uri.EscapeDataString(actorId)}/inventory/remove",
                authorization,
                new InventoryRemovalRequestDto(
                    item.ItemId,
                    item.Name,
                    item.Category,
                    quantity,
                    reason,
                    idempotencyKey),
                InternalToken(configuration));
            return result.Error is not null
                ? ServiceJsonResult<AssetMutationResultDto>.Failed(result.Error)
                : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                    result.Value!.Completed,
                    result.Value.Message));
        }

        var companyResult = await production.PostJsonAsync<CompanyInventoryMutationRequestDto, CompanyAssetMutationResponseDto>(
            $"companies/{Uri.EscapeDataString(actorId)}/assets/inventory/remove",
            authorization,
            new CompanyInventoryMutationRequestDto(
                actorPlayerId,
                item.ItemId,
                item.Name,
                item.Category,
                quantity,
                "trade_offer_reserve",
                reason,
                idempotencyKey),
            InternalToken(configuration));
        return companyResult.Error is not null
            ? ServiceJsonResult<AssetMutationResultDto>.Failed(companyResult.Error)
            : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                companyResult.Value!.Completed,
                companyResult.Value.Message));
    }

    private static async Task<ServiceJsonResult<AssetMutationResultDto>> GrantActorItemAsync(
        string actorType,
        string actorId,
        string actorPlayerId,
        ActorItemDto item,
        int quantity,
        string reason,
        string idempotencyKey,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        IConfiguration configuration)
    {
        if (actorType == TradeActorKinds.Player)
        {
            var result = await economy.PostJsonAsync<InventoryGrantRequestDto, InventoryMutationResponseDto>(
                $"players/{Uri.EscapeDataString(actorId)}/inventory/grant",
                authorization,
                new InventoryGrantRequestDto(
                    item.ItemId,
                    item.Name,
                    item.Category,
                    quantity,
                    "trade_contract_item",
                    reason,
                    idempotencyKey),
                InternalToken(configuration));
            return result.Error is not null
                ? ServiceJsonResult<AssetMutationResultDto>.Failed(result.Error)
                : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                    result.Value!.Completed,
                    result.Value.Message));
        }

        var companyResult = await production.PostJsonAsync<CompanyInventoryMutationRequestDto, CompanyAssetMutationResponseDto>(
            $"companies/{Uri.EscapeDataString(actorId)}/assets/inventory/grant",
            authorization,
            new CompanyInventoryMutationRequestDto(
                actorPlayerId,
                item.ItemId,
                item.Name,
                item.Category,
                quantity,
                "trade_contract_item",
                reason,
                idempotencyKey),
            InternalToken(configuration));
        return companyResult.Error is not null
            ? ServiceJsonResult<AssetMutationResultDto>.Failed(companyResult.Error)
            : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                companyResult.Value!.Completed,
                companyResult.Value.Message));
    }

    private static async Task<ServiceJsonResult<AssetMutationResultDto>> DebitActorGoldAsync(
        string actorType,
        string actorId,
        string actorPlayerId,
        int amount,
        string reason,
        string idempotencyKey,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        IConfiguration configuration)
    {
        if (actorType == TradeActorKinds.Player)
        {
            var result = await economy.PostJsonAsync<WalletDebitRequestDto, WalletDebitResponseDto>(
                $"players/{Uri.EscapeDataString(actorId)}/wallet/debit",
                authorization,
                new WalletDebitRequestDto(amount, "trade_contract_purchase", reason, idempotencyKey),
                InternalToken(configuration));
            return result.Error is not null
                ? ServiceJsonResult<AssetMutationResultDto>.Failed(result.Error)
                : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                    result.Value!.Completed,
                    result.Value.Message));
        }

        var companyResult = await production.PostJsonAsync<CompanyWalletMutationRequestDto, CompanyAssetMutationResponseDto>(
            $"companies/{Uri.EscapeDataString(actorId)}/assets/wallet/debit",
            authorization,
            new CompanyWalletMutationRequestDto(
                actorPlayerId,
                amount,
                "trade_contract_purchase",
                reason,
                idempotencyKey),
            InternalToken(configuration));
        return companyResult.Error is not null
            ? ServiceJsonResult<AssetMutationResultDto>.Failed(companyResult.Error)
            : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                companyResult.Value!.Completed,
                companyResult.Value.Message));
    }

    private static async Task<ServiceJsonResult<AssetMutationResultDto>> CreditActorGoldAsync(
        string actorType,
        string actorId,
        string actorPlayerId,
        int amount,
        string reason,
        string idempotencyKey,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        IConfiguration configuration)
    {
        if (actorType == TradeActorKinds.Player)
        {
            var result = await economy.PostJsonAsync<WalletCreditRequestDto, WalletCreditResponseDto>(
                $"players/{Uri.EscapeDataString(actorId)}/wallet/credit",
                authorization,
                new WalletCreditRequestDto(amount, "trade_contract_sale", reason, idempotencyKey),
                InternalToken(configuration));
            return result.Error is not null
                ? ServiceJsonResult<AssetMutationResultDto>.Failed(result.Error)
                : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                    result.Value!.Completed,
                    result.Value.Message));
        }

        var companyResult = await production.PostJsonAsync<CompanyWalletMutationRequestDto, CompanyAssetMutationResponseDto>(
            $"companies/{Uri.EscapeDataString(actorId)}/assets/wallet/credit",
            authorization,
            new CompanyWalletMutationRequestDto(
                actorPlayerId,
                amount,
                "trade_contract_sale",
                reason,
                idempotencyKey),
            InternalToken(configuration));
        return companyResult.Error is not null
            ? ServiceJsonResult<AssetMutationResultDto>.Failed(companyResult.Error)
            : ServiceJsonResult<AssetMutationResultDto>.Succeeded(new AssetMutationResultDto(
                companyResult.Value!.Completed,
                companyResult.Value.Message));
    }

    private static async Task RefundSellerReservationAsync(
        TradeOfferDto offer,
        string actorPlayerId,
        string contractId,
        string authorization,
        EconomyServiceClient economy,
        ProductionServiceClient production,
        IConfiguration configuration)
    {
        await GrantActorItemAsync(
            offer.SellerType,
            offer.SellerId,
            offer.SellerType == TradeActorKinds.Company ? offer.CreatorPlayerId : offer.SellerId,
            new ActorItemDto(offer.ItemId, offer.ItemName, offer.Category, offer.Quantity, string.Empty),
            offer.Quantity,
            $"Refunded reserved item after failed trade contract {contractId}.",
            $"trade:{contractId}:seller-refund",
            authorization,
            economy,
            production,
            configuration);
    }

    private static async Task<IResult?> ValidateBuyerAccessAsync(
        TradeOfferDto offer,
        string actorPlayerId,
        string authorization,
        ProductionServiceClient production)
    {
        if (offer.BuyerType == TradeActorKinds.Player)
        {
            return string.Equals(offer.BuyerId, actorPlayerId, StringComparison.OrdinalIgnoreCase)
                ? null
                : Results.Json(
                    new ErrorResponse("You cannot accept a trade offer addressed to another player."),
                    statusCode: StatusCodes.Status403Forbidden);
        }

        var company = await GetCompanyAssetsAsync(production, offer.BuyerId, actorPlayerId, authorization);
        return company.Error;
    }

    private static async Task<IResult?> ValidateCancelAccessAsync(
        TradeOfferDto offer,
        string actorPlayerId,
        string authorization,
        ProductionServiceClient production)
    {
        if (string.Equals(offer.CreatorPlayerId, actorPlayerId, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        if (offer.SellerType == TradeActorKinds.Player)
        {
            return string.Equals(offer.SellerId, actorPlayerId, StringComparison.OrdinalIgnoreCase)
                ? null
                : Results.Json(
                    new ErrorResponse("Only the trade creator or seller can cancel this offer."),
                    statusCode: StatusCodes.Status403Forbidden);
        }

        var company = await GetCompanyAssetsAsync(production, offer.SellerId, actorPlayerId, authorization);
        return company.Error;
    }

    private static async Task<IResult?> ValidateTradeOfferListAccessAsync(
        string? actorType,
        string? actorId,
        string playerId,
        string authorization,
        ProductionServiceClient production)
    {
        var normalizedActorType = NormalizeActorType(actorType, string.Empty);
        var normalizedActorId = NormalizeIdOrDefault(actorId, string.Empty);
        if (normalizedActorType is null || string.IsNullOrWhiteSpace(normalizedActorId))
        {
            return null;
        }

        if (normalizedActorType == TradeActorKinds.Player)
        {
            return string.Equals(normalizedActorId, playerId, StringComparison.OrdinalIgnoreCase)
                ? null
                : Results.Json(
                    new ErrorResponse("You cannot list another player's private trade offers."),
                    statusCode: StatusCodes.Status403Forbidden);
        }

        var company = await GetCompanyAssetsAsync(production, normalizedActorId, playerId, authorization);
        return company.Error;
    }

    private static async Task<ServiceJsonResult<CompanyAssetsDto>> GetCompanyAssetsAsync(
        ProductionServiceClient production,
        string companyId,
        string actorPlayerId,
        string authorization)
    {
        return await production.GetJsonAsync<CompanyAssetsDto>(
            $"companies/{Uri.EscapeDataString(companyId)}/assets?actorPlayerId={Uri.EscapeDataString(actorPlayerId)}",
            authorization);
    }

    private static PlayerAccessResult ValidateBearerPlayer(HttpRequest request, DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        return token.IsValid
            ? PlayerAccessResult.Allowed(token.PlayerId!)
            : PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
    }

    private static PlayerAccessResult ValidatePlayerAccess(
        string playerId,
        HttpRequest request,
        DevTokenValidator tokens)
    {
        var token = tokens.Validate(request.Headers.Authorization.ToString());
        if (!token.IsValid)
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("A valid bearer token is required."),
                statusCode: StatusCodes.Status401Unauthorized));
        }

        if (!string.Equals(token.PlayerId, playerId, StringComparison.OrdinalIgnoreCase))
        {
            return PlayerAccessResult.Denied(Results.Json(
                new ErrorResponse("You cannot access another player's market."),
                statusCode: StatusCodes.Status403Forbidden));
        }

        return PlayerAccessResult.Allowed(token.PlayerId!);
    }

    private static string InternalToken(IConfiguration configuration)
    {
        return configuration["FF_INTERNAL_SERVICE_TOKEN"]
            ?? "ff-development-internal-token-change-me";
    }

    private static string? NormalizeActorType(string? actorType, string fallback)
    {
        var normalized = string.IsNullOrWhiteSpace(actorType)
            ? fallback
            : actorType.Trim().ToLowerInvariant();
        return normalized is TradeActorKinds.Player or TradeActorKinds.Company ? normalized : null;
    }

    private static string NormalizeIdOrDefault(string? value, string defaultValue)
    {
        var normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
        return string.IsNullOrWhiteSpace(normalized) ? defaultValue.Trim().ToLowerInvariant() : normalized;
    }

    private static string BuildQuery(params (string Key, string? Value)[] values)
    {
        var parts = values
            .Where(value => !string.IsNullOrWhiteSpace(value.Value))
            .Select(value => $"{Uri.EscapeDataString(value.Key)}={Uri.EscapeDataString(value.Value!)}")
            .ToArray();
        return parts.Length == 0 ? string.Empty : $"?{string.Join('&', parts)}";
    }
}

internal static class TradeActorKinds
{
    public const string Player = "player";
    public const string Company = "company";
}

internal sealed record TradeOfferGatewayRequest(
    string? OfferId,
    string? SellerType,
    string? SellerId,
    string? BuyerType,
    string? BuyerId,
    string? ItemId,
    int Quantity,
    int PricePerUnit,
    string? IdempotencyKey);

internal sealed record TradeOfferActionRequest(string? IdempotencyKey, string? Reason);

internal sealed record TradeOfferGatewayResponse(
    bool Completed,
    string Message,
    TradeOfferDto? Offer,
    TradeContractDto? Contract,
    int TotalPrice);

internal sealed record TradeOfferListResponseDto(TradeOfferDto[] Offers, DateTimeOffset UpdatedAt);

internal sealed record TradeOfferDto(
    string OfferId,
    string CreatorPlayerId,
    string SellerType,
    string SellerId,
    string BuyerType,
    string BuyerId,
    string ItemId,
    string ItemName,
    string Category,
    int QualityTier,
    int Quantity,
    int PricePerUnit,
    string Status,
    string IdempotencyKey,
    string? AcceptIdempotencyKey,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ExpiresAt,
    DateTimeOffset? RespondedAt);

internal sealed record TradeContractDto(
    string ContractId,
    string OfferId,
    string AcceptedByPlayerId,
    string Status,
    string FailureReason,
    string IdempotencyKey,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? FulfilledAt);

internal sealed record TradeOfferMutationResponseDto(
    bool Completed,
    string Message,
    TradeOfferDto? Offer,
    TradeContractDto? Contract);

internal sealed record CreateTradeOfferRequestDto(
    string OfferId,
    string CreatorPlayerId,
    string SellerType,
    string SellerId,
    string BuyerType,
    string BuyerId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    int PricePerUnit,
    string IdempotencyKey,
    DateTimeOffset? ExpiresAt);

internal sealed record AcceptTradeOfferRequestDto(string AcceptedByPlayerId, string IdempotencyKey);

internal sealed record CancelTradeOfferRequestDto(string ActorPlayerId, string? Reason, string? IdempotencyKey);

internal sealed record FulfillTradeContractRequestDto(string IdempotencyKey);

internal sealed record FailTradeContractRequestDto(string Reason);

internal sealed record CompanyInventoryMutationRequestDto(
    string ActorPlayerId,
    string ItemId,
    string ItemName,
    string Category,
    int Quantity,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record CompanyWalletMutationRequestDto(
    string ActorPlayerId,
    int Amount,
    string EntryType,
    string Reason,
    string IdempotencyKey);

internal sealed record CompanyAssetMutationResponseDto(
    bool Completed,
    string Message,
    CompanyAssetsDto Assets);

internal sealed record ActorItemDto(
    string ItemId,
    string Name,
    string Category,
    int Quantity,
    string Description);

internal sealed record AssetMutationResultDto(bool Completed, string Message);
