# NFT Auction Flow

1. Deploy NFT Token Contract (Owner: Alice)
2. Deploy NFT Auction Contract (Owner: z)
3. Alice mint NFT(1) cho Bob ở token contract
4. Alice mint NFT(2) to David ở token contract
5. Bob thêm NFT(1) vào trong auction contract (giá khởi điểm: 10 ETH)
6. Bắt đầu vòng bid nft(1)
7. David thêm NFT(2) vào trong auction contract (giá khởi điểm: 100 ETH)
8. Charlie bid NFT(1) (giá: 20 ETH)
   1. Charlie nạp tiền vào auction contract cho nft(1)
   2. cập nhật thông tin của nft(1)
9. Evan bid nft(1) (giá: 30 eth)
   1. trả lại tiền cho charlie
   2. cập nhật thông tin của nft(1)
10. Hết thời gian bid nft(1)
   1. chuyển nft(1) cho evan
   2. chuyển tiền cho bob
11. Bắt đầu vòng bid nft(2)
12. Hết thời gian bid nft(2)
    1. trả nft cho david
