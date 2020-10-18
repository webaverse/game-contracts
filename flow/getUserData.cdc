import WebaverseAccount from WEBAVERSEACCOUNTADDRESS
import WebaverseNFT from WEBAVERSENFTADDRESS

pub fun main() : [String?] {
    let acct = getAccount(ARG0)
    
    let collectionRef = acct.getCapability(/public/AccountCollection)!.borrow<&{WebaverseAccount.WebaverseAccountStatePublic}>()
      ?? panic("Could not borrow capability from public collection")

    return [
      collectionRef.keyValueMap["name"],
      collectionRef.keyValueMap["avatarUrl"],
      collectionRef.keyValueMap["avatarFilename"],
      collectionRef.keyValueMap["ftu"]
    ]
}
