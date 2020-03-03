
pragma solidity >=0.4.22 <0.6.0;
pragma experimental ABIEncoderV2;

contract kyc{

    // Customer structure
    struct customer{
        string userName;
        string customerData;
        uint rating;
        uint upvotes;
        address bank;
        string password;
    }

    // Bank structure
    struct bank{
        string name;
        address ethAddress;
        uint rating;
        uint KycCount;
        string regNum;
    }

    // KYC_Request structure
    struct kycRequest{
        string user;
        string data;
        address bankAddress;
        bool isAllowed;
    }


    mapping(string => kycRequest[])  reqList;               // mapping to store lists of all the requests mapped to name of the customer
    mapping(string => customer)  customerList;              // mapping to store all the customer names mapped to name of the customer
    mapping(string => customer)  finalCustomerList;         // similar to above mapping, but servers different purpose
    mapping(address => bank) bankList;                      // lists of all the mapped to thier names
    mapping(string => uint) kycIndex;                       // This is used to store the index of the kycreq to access when needed in first mapping
    mapping(address => mapping(string => bool)) votedCustomers;   // stores whether partivular bank has voted particular customer or not for not repeating the vote
    mapping(address => kycRequest[]) bankKycRequests;             // stores all the req's of the specific bank mapped to its name.
    mapping(address => mapping(address => bool)) votedBanks;      // same as the voted customer mapping, but this stores voting regarding the banks.
    mapping(string => address) accessHistoryData;                 // this stores the ingo about the bank which has last made changes. mapped to customer name.
    uint totalBanks = 0;        // variable for total anks count
    address admin;              // to store the admin address.

    constructor() public{

        // when the admin deploys the contract on to the network, then store his address
        admin = msg.sender;
    }

    /* Function to add the request to the request list */
    function addRequest(string memory customerName,string memory customerData) public returns(bool){

        // checks if the req is already present
        if(kycIndex[customerData] == 0){

            // if the bank's < 0.5, then set isAllowed paramter to false
            if(bankList[msg.sender].rating <= uint(50)){
                kycIndex[customerData] = reqList[customerName].push(kycRequest(customerName,customerData,msg.sender,false));
                bankKycRequests[msg.sender].push(kycRequest(customerName,customerData,msg.sender,false));
            }
            // if not allow him
            else{
                kycIndex[customerData] = reqList[customerName].push(kycRequest(customerName,customerData,msg.sender,true));
                bankKycRequests[msg.sender].push(kycRequest(customerName,customerData,msg.sender,true));
            }

            // increase the kyc count of that bank
            bankList[msg.sender].KycCount++;

            return true;
        }

        // if alreadypresent return false flag
        else{
            return false;
        }

    }

    /* Function to add the customer in the customer list  */
    function addCustomer(string calldata customerName,string calldata custData) external returns(bool){

        // check if the requested banker is allowed to add the customer
        if(reqList[customerName][kycIndex[custData]-1].isAllowed == true || (msg.sender == admin)){
            customerList[customerName].userName = customerName;
            customerList[customerName].customerData = custData;
            customerList[customerName].rating = 0;
            customerList[customerName].upvotes = 0;
            customerList[customerName].bank = msg.sender;
            return true;
        }
        // if not return false`
        else{
            return false;
        }
    }

    /* Function to remove the request from the request list */
    function removeRequest(string calldata customerName,string calldata data) external returns(bool){

        // check if that requested kyc data is present
        if(kycIndex[data] != 0){

            uint index = kycIndex[data]-1;
            uint lastindex = reqList[customerName].length-1;

            // if the requested index is below the range
            if(index < lastindex+1){

                // delete that particular req from the mapping
                delete(reqList[customerName][index]);

                // reset the index's array to zero, since the data is deleted
                kycIndex[data] = 0;

                return true;
            }

            // else return false
            else{
                return false;
            }

        }

        // if the requested data is not pressented, then return false.
        else{
            return false;
        }
    }


    /* function to remove the customer from the customer list */
    function removeCustomer(string calldata customerName) external returns(bool){

        // check whether the customer is presented in the list
        if( (bytes(customerList[customerName].userName).length) != 0){

            delete(customerList[customerName]);
            return true;
        }
        // if not, return false
        else{
            return false;
        }
    }

    /* Function to modify the customer's data */
    function modifyCustomer(string calldata customerName,string calldata customerData) external returns(bool){

        // check if the customer is present in the list
        if(bytes(customerList[customerName].userName).length != 0 ){

            // if that customer is present in the final_customer list, then delete his entry there
            if( (bytes(finalCustomerList[customerName].userName).length) != 0){

                delete(finalCustomerList[customerName]);
            }
            // reset his upvotes to zero in customerList
            customerList[customerName].upvotes = 0;

            // reset his rating to zero in customerList
            customerList[customerName].rating = 0;

            // modify the given data
            customerList[customerName].customerData = customerData;

            // set the access hoistory to the current banker who is changing the data
            accessHistoryData[customerName] = msg.sender;

            return true;
        }

        // if the customer is not present, return false
        else{
            return false;
        }
    }

    /* Function to get the customer data */
    function viewCustomer(string calldata customerName,string calldata password) view external returns(string memory){

        // flag
        string memory flag = "false";

        // check if the customer is presentin the list
        if(bytes(customerList[customerName].userName).length != 0 ){

            // if the customer's password is not set
            if(bytes(customerList[customerName].password).length == 0){

                // check whether the incoming password is 0
                if( keccak256(abi.encodePacked(password)) == keccak256(abi.encodePacked("O")) ){

                    string memory data = customerList[customerName].customerData;
                    return data;
                }

                // if not 0, return false flag
                else{
                    return flag;
                }
            }

            // if the customer's passwors is set, then validate the given password
            else{
                if( keccak256(abi.encodePacked(password)) == keccak256(abi.encodePacked(customerList[customerName].password)) ){
                    string memory data = customerList[customerName].customerData;
                    return data;
                }
                else{
                    return flag;
                }
           }
        }

        // if customer is not present, return flase
        else{
            return flag;
        }
    }

    /* Fucntion to upvote the customer by the bank */
    function upvoteCustomer(string calldata customerName) external returns(bool){

        // if the bank hasn't upvoted that customer
        if(votedCustomers[msg.sender][customerName] == false){
            // upvote the customer
            uint votes = customerList[customerName].upvotes++;

            // record the vting to that customer to avoid rigging
            votedCustomers[msg.sender][customerName] = true;

            // call the helper function to calculate the rating
            customerList[customerName].rating = calRating(votes);

            // check if that customer rating is more than the threshold to add into final_customer list
            if(customerList[customerName].rating > uint(50)){
                finalCustomerList[customerName] = customerList[customerName];
            }

            return true;
        }

        // if already voted that customer, return false
        else{
            return false;
        }

    }

    /* Helper function to calculate the rating of the customer */
    function calRating(uint votes) view private returns(uint){
        return votes/totalBanks;
    }

    /* Function to get all the requests of a bank  */
    function getBankRequests() view external returns(kycRequest[] memory){

        kycRequest[] memory list = bankKycRequests[msg.sender];
        return list;
    }

    /* Function to upvote a bank */
    function upvoteBank(address bankAdd) external returns(bool){
        // check if already voted that bank
        if(votedBanks[msg.sender][bankAdd] == false){
            bankList[bankAdd].rating++;
            return true;
        }

        // if voted already, retun false
        else{
            return false;
        }
    }

    /* Function to get the customer rating */
    function getCustRating(string calldata customerName) view external returns(uint){

        uint rating = customerList[customerName].rating;
        return rating;
    }

    /* Function to get the bank rating */
    function getBankRating(address bankAdd) view external returns(uint){
        uint rating = bankList[bankAdd].rating;
        return rating;
    }

    /* Function to get the access history of the customer */
    function accessHistory(string calldata customerName) view external returns(address){
        address bank1 = accessHistoryData[customerName];
        return bank1;
    }

    /*  Function to get set the password for the customer */
    function setPassword(string calldata userName,string calldata password) external returns(bool){
       if(bytes(customerList[userName].userName).length != 0){
           customerList[userName].password = password;
            return true;
       }
       else{
           return false;
       }
    }

    /*  Function to get the details of a bank */
    function getBankDetails(address bankAdd) view external returns(bank memory){
        if(bytes(bankList[bankAdd].name).length != 0){
            bank memory bank2 = bankList[bankAdd];
            return bank2;
        }
    }

    /* Modifier to alaoow only the admin to make any changes */
    modifier onlyAdmin{
        require(msg.sender == admin);
        _;
    }

    /*  Function to add the bank by the admin */
    function addBank(string calldata bankName,address bankAdd,string calldata regNumber) onlyAdmin external returns(bool){

            bankList[bankAdd].name = bankName;
            bankList[bankAdd].ethAddress = bankAdd;
            bankList[bankAdd].rating = 60;
            bankList[bankAdd].KycCount = 0;
            bankList[bankAdd].regNum = regNumber;
            totalBanks++;

            return true;
    }

    /* Function to remove the bank from the network by the admin */
    function removeBank(address bankAdd) onlyAdmin external returns(bool){

            delete(bankList[bankAdd]);
            totalBanks--;

            return true;
    }

}
