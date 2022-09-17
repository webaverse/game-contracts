// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./WebaverseVoucher.sol";

contract WebaverseERC1155 is
    ERC1155Upgradeable,
    WebaverseVoucher,
    OwnableUpgradeable
{
    using ECDSA for bytes32;
    using Strings for uint256;

    string private _name;
    string private _symbol;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) private _tokenBalances;
    string private _webaBaseURI; // Base URI of the collection for Webaverse
    uint256 public currentTokenId; // State variable for storing the latest minted token id
    bool internal isPublicallyMintable; // whether anyone can mint tokens in this copy of the contract
    mapping(uint256 => address) internal minters; // map of tokens to minters

    event Claim(address signer, address claimer, uint256 indexed id);
    event ExternalClaim(
        address indexed externalContract,
        address signer,
        address claimer,
        uint256 indexed id
    );

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
    ) public initializer {
        _name = name_;
        _symbol = symbol_;
        __Ownable_init_unchained();
        __ERC1155_init(baseURI_);
        _webaBaseURI = baseURI_;
        _webaverse_voucher_init();
    }

    /**
     * @return Returns the name of the collection.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return Returns the symbol of the collection.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return Returns the base URI of the host to fetch the attributes from (default empty).
     */
    function baseURI() public view returns (string memory) {
        return _webaBaseURI;
    }

    /**
     * @dev Update or change the Base URI of the collection for Webaverse NFTs
     * @param baseURI_ The base URI of the host to fetch the attributes from e.g. https://ipfs.io/ipfs/.
     */
    function setBaseURI(string memory baseURI_) public onlyOwner {
        _webaBaseURI = baseURI_;
    }

    /**
     * @param tokenId The id of the token for which the balance is being fetched.
     * @return Returns the total balance of the token.
     */
    function getTokenBalance(uint256 tokenId) public view returns (uint256) {
        return _tokenBalances[tokenId];
    }

    /**
     * @dev Update or change the isPublicallyMintable for Webaverse NFTs
     * @param _isPublicallyMintable True: mint can be called False: mint can't be called
     */
    function setPublicallyMintable(bool _isPublicallyMintable) public onlyOwner {
        isPublicallyMintable = _isPublicallyMintable;
    }

    /**
     * @return Returns isPublicallyMintable.
     */
    function getPublicallyMintable() public view returns (bool) {
        return isPublicallyMintable;
    }

    /**
     * @return Returns the token URI against a particular token id.
     * e.g. https://tokens.webaverse.com/1
     */
    function uri(uint256 _id) public view override returns (string memory) {
        string memory baseURI = baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _id.toString())) : '';
    }

    /**
     * @dev get token contentURL
     * @param tokenId Token id to set the contentURL to
     * @param _uri The contentURL to set for the token
     */
    function setTokenContentURL(uint256 tokenId, string memory _uri)
        internal
    {
        require(bytes(_uri).length > 0, "ERC1155: URI must not be empty");
        _tokenURIs[tokenId] = _uri;
    }

    /**
     * @dev get token contentURL
     * @param tokenId Token id to get the contentURL
     */
    function getTokenContentURL(uint256 tokenId) public view returns (string memory) 
    {
        require(currentTokenId >= tokenId, "ERC1155: contentURL query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    function getTokenIdsByOwner(address owner) public view returns (uint256[] memory, uint256) {
        uint256[] memory ids = new uint256[](currentTokenId);
        uint256 index = 0;
        for (uint256 i = 1; i <= currentTokenId; i++) {
            if(minters[i] == owner) 
            {
                ids[index] = i;
                index++;
            }
        }
        return (ids, index);
    }

    /**
     * @notice Mints a single NFT with given parameters.
     * @param to The address on which the NFT will be minted.
     **/
    function mint(
        address to,
        uint256 balance,
        string memory _uri,
        bytes memory data
    ) public {
        require(isPublicallyMintable, "ERC1155: Public Mint Closed")
        uint256 tokenId = getNextTokenId();
        _mint(to, tokenId, balance, data);
        setTokenContentURL(tokenId, _uri);
        _incrementTokenId();
        _tokenBalances[tokenId] = balance;
        minters[tokenId] = to;
    }

    /**
     * @notice Mints batch of NFTs with given parameters.
     * @param to The address to which the NFTs will be minted in batch.
     * @param uris The URIs of all the the NFTs.
     * @param balances The balances of all the NFTs as per the ERC1155 standard.
     **/
    function mintBatch(
        address to,
        string[] memory uris,
        uint256[] memory balances,
        bytes memory data
    ) public {
        require(
            uris.length == balances.length,
            "WBVRSERC1155: URIs and balances length mismatch"
        );
        uint256[] memory ids = new uint256[](uris.length);
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tokenId = getNextTokenId();
            ids[i] = tokenId;
            setTokenContentURL(tokenId, uris[i]);
            minters[tokenId] = to;
        }
        _mintBatch(to, ids, balances, data);
    }

    /**
     * @notice Redeems an NFTVoucher for an actual NFT, authorized by the owner.
     * @param signer The address of the account which signed the NFT Voucher.
     * @param claimer The address of the account which will receive the NFT upon success.
     * @param data The data to store.
     * @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
     * @dev Verification through ECDSA signature of 'typed' data.
     * @dev Voucher must contain valid signature, nonce, and expiry.
     **/
    function mintServerDropNFT(address signer, address claimer, bytes memory data, NFTVoucher calldata voucher)
        public
    {
        require(owner() == signer, "Wrong signature!");

        uint256 tokenId = getNextTokenId();
        _mint(claimer, tokenId, voucher.balance, data);

        // setURI with token's contentURL of verified voucher
        setTokenContentURL(tokenId, voucher.contentURL);
        _incrementTokenId();
        _tokenBalances[tokenId] = voucher.balance;
        minters[tokenId] = claimer;
    }

    /**
     * @notice Redeems an NFTVoucher for an actual NFT, authorized by the owner.
     * @param signer The address of the account which signed the NFT Voucher.
     * @param claimer The address of the account which will receive the NFT upon success.
     * @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
     * @dev Verification through ECDSA signature of 'typed' data.
     * @dev Voucher must contain valid signature, nonce, and expiry.
     **/
    function claim(address signer, address claimer, NFTVoucher calldata voucher)
        public
    {
        // make sure signature is valid and get the address of the signer
        // address signer = verifyVoucher(voucher);

        require(
            balanceOf(signer, voucher.tokenId) != 0,
            "WBVRS: Authorization failed: Invalid signature"
        );

        require(
            minters[voucher.tokenId] == signer,
            "WBVRS: Authorization failed: Invalid signature"
        );

        minters[voucher.tokenId] = claimer;
        // transfer the token to the claimer
        _safeTransferFrom(
            signer,
            claimer,
            voucher.tokenId,
            voucher.balance,
            "0x01"
        );
    }

    /**
     * @notice Redeems an NFTVoucher for an actual NFT, authorized by the owner from an external contract.
     * @param claimer The address of the account which will receive the NFT upon success.
     * @param contractAddress The address of the contract from which the token is being transferred
     * @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
     * @dev Verification through ECDSA signature of 'typed' data.
     * @dev Voucher must contain valid signature, nonce, and expiry.
     **/
    function externalClaim(
        address claimer,
        address contractAddress,
        NFTVoucher calldata voucher
    ) public returns (uint256) {
        IERC1155Upgradeable externalContract = IERC1155Upgradeable(
            contractAddress
        );
        // make sure signature is valid and get the address of the signer
        address signer = verifyVoucher(voucher);

        require(
            externalContract.balanceOf(signer, voucher.tokenId) != 0,
            "WBVRS: Authorization failed: Invalid signature"
        );
        require(
            externalContract.isApprovedForAll(signer, address(this)),
            "WBVRS: Aprroval not set for WebaverseERC1155"
        );

        // transfer the token to the claimer
        externalContract.safeTransferFrom(
            signer,
            claimer,
            voucher.tokenId,
            voucher.balance,
            "0x01"
        );
        return voucher.tokenId;
    }

    /**
     * @notice Redeems an NFTVoucher for an actual NFT, authorized by the owner from an external contract.
     * @param to The address of the account which will receive the NFT.
     * @param id The token id of the NFT to be transferred.
     * @param amount The balance of the token to be transffered.
     **/
    function safeTransfer(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        safeTransferFrom(_msgSender(), to, id, amount, data);
    }

    /**
     * @dev returns the next token id to be minted
     */
    function getNextTokenId() public view returns (uint256) {
        return currentTokenId + 1;
    }

    /**
     * @dev increments the value of _currentTokenId
     */
    function _incrementTokenId() internal {
        currentTokenId++;
    }

    /**
     * @notice Using low level assembly call to fetch the chain id of the blockchain.
     * @return Returns the chain id of the current blockchain.
     **/
    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable)
        returns (bool)
    {
        return ERC1155Upgradeable.supportsInterface(interfaceId);
    }
}
