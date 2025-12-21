import {OrderActs} from "orderbook/libs/OrderActs.sol";

library SettlementRoles {
    using OrderActs for OrderActs.Order;

    function resolve(
        OrderActs.Fill memory f,
        OrderActs.Order memory o
    )
        internal
        pure
        returns (address nftHolder, address spender, uint256 tokenId)
    {
        // NOTE: Does NOT check whether isBid purposefully so `settle` can revert `InvalidOrderSide`.

        if (o.isAsk()) {
            // order creator holds nft (nftHolder)
            // fill actor buys the nft (spender)
            // the tokenId is specified by order creator (tokenId)
            return (o.actor, f.actor, o.tokenId);
        } else {
            // if `Side` is anything but `Bid` / `Ask` this should revert in engine

            // if is `Bid` the correct roles are:
            // fill actor responds to a bid with a provided nft (nftHolder)
            // order creator will pay for the token provided in fill (spender)

            // if order is a collection bid:
            // true: any tokenId specified in `fill` will work as long as its the correct collection
            // false: the tokenId provided in fill is !IGNORED! order.tokenId
            return (
                f.actor,
                o.actor,
                o.isCollectionBid ? f.tokenId : o.tokenId
            );
        }
    }
}
