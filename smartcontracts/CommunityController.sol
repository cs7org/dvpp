pragma solidity ^0.4.24;

contract CommunityController {
    
    //addresses
    address public owner;
    address public contractor;
    address constant internal nobody = 0x0000000000000000000000000000000000000000; // use genesis address if not contracted
    //address constant internal community = 0x0000000000000000000000000000000000000001;
    
    //mappings
    mapping(address => bool) public registered; //true if address is registered
    mapping(address => uint24) private SOC; //currrent SOC of address in m%, , uint24 
    mapping(address => int32) private Pres; //current Pres of address (Consumer counting arrow system) in mW, uint32 for up to 4MW
    mapping(address => uint32) private PoptCh; //optimal charging operation point of address in mW, uint32 for up to 4 MW
    mapping(address => uint32) private PoptDch; //optimal discharging operation point of address in mW, uint32 for up to 4 MW
    mapping(uint24 => address) public RegisteredAddresses;  //address of registered index, uint24 for up to 16 Mio participants 
    mapping(address => uint24) public RegistrationIndex;  //index of registered address, uint24 for up to 16 M participants 
    mapping(address => uint) private AdrBalance;  //balance of the addresses
    mapping(address => uint32) private LastActiveBlock; //last blocknumber where address x did setState(), uint32 for up to 4 G blocks
    mapping(address => uint32) private Pmax; //Pmax of grid connection (not of battery system!) 32 for up to 4MW
    
    //other
    uint24 public numberOfAdresses=0; //total number of registered addresses, uint24 for up to 16 M participants 
    int48[2] private setPoint = [0,0]; //setpoint of DVPP, int48 for up to 140 GW
    uint32 public price = 1000000000; //price per mW per block, uint32 for up to 4e9
    uint32 constant public price_internal = 500000000;
    uint80 private PricePerBlock = 0; //uint96
    int48[2] private PresTot = [0,0]; //int48 for up to 140 GW
    uint32 private BlockCounterNewBlock = 0;
    uint48 PmaxTot = 0; //maximum over grid connection (for internal balancing)
    
    //modifiers
    modifier onlyOwner()
    {
        require(msg.sender == owner, "onlyOwner");
        _;
    }
    
    modifier onlyRegistered()
    {
        require(registered[msg.sender] == true, "onlyRegistered");
        _;
    }
    
    modifier onlyNonregistered()
    {
        require(registered[msg.sender] == false, "onlyNonregistered");
        _;
    }
    
    modifier onlyContractor()
    {
        require(msg.sender == contractor, "onlyContractor");
        _;
    }
    
    modifier notContractor()
    {
        require(msg.sender != contractor, "notContractor");
        _;
    }
    
    modifier onlyNotUnderContract
    {
        require(contractor == nobody, "contractor!=nobody.");
        require(setPoint[0]==0&&setPoint[1]==0, "setPoint[0]!=0||setPoint[1]!=0.");
        _;
    }
    
    modifier onlyOnePerBlock
    {
        require(LastActiveBlock[msg.sender]<block.number, "onlyOnePerBlock");
        LastActiveBlock[msg.sender] = uint32(block.number);
        _;
    }
    
    modifier onlyInvolvedParty
    {
        require(msg.sender == contractor || registered[msg.sender] == true, "onlyInvolvedParty");
        _;
    }
    
    //constructor
    constructor() public  //TODO rename to constructor()
    {
        owner = msg.sender;
        contractor = nobody;
        //register(); //register owner 
    }
    
    //DVPP new setPoint //TODO 
    function contractNewSetPoint(int48 newSetValue, uint32 MaxPrice) external payable onlyNotUnderContract onlyNonregistered onlyOnePerBlock
    {
        require(MaxPrice>=price, "invalid MaxPrice"); // in future require(MaxPrice>=price,'price in contract > MaxPrice');
        require(newSetValue!=0, "invalid NewSetValue");
        require(flexibilityAvailable(newSetValue,10000), "no flex.");
        
        if (newSetValue<0)
        {
            PricePerBlock = uint48(-newSetValue)*price;
        }
        else
        {
            PricePerBlock = uint48(newSetValue)*price;
        }
        
        if(msg.value>=4*PricePerBlock) //minimum contract of 1 Minute / 4 blocks
        {
            //contract DVPP
            setPoint[(block.number)%2] = newSetValue;
            contractor = msg.sender;
            AdrBalance[contractor] += msg.value;
        }
        else
        {
            revert("invalid msg.value");
        }
    }

    function flexibilityAvailable(int48 newSetValue, uint24 SOCborder) public view returns (bool)
    {
        require(SOCborder <= 50000 && SOCborder >= 1000, "invalid SOCborder");
        uint48 SOCavg = 0;
        uint24 SOCmax = 0;
        uint24 SOCmin = 100000;
        for (uint24 i = 0; i<numberOfAdresses; i++)
        {
            SOCavg += SOC[RegisteredAddresses[i]];
            if (SOC[RegisteredAddresses[i]]>SOCmax)
            {
                SOCmax = SOC[RegisteredAddresses[i]];
            }
            if (SOC[RegisteredAddresses[i]]<SOCmin)
            {
                SOCmin = SOC[RegisteredAddresses[i]];
            }
        }
        SOCavg = SOCavg / numberOfAdresses; 
        //PresTotal = PresTot[(block.number)%2]-setPoint[(block.number)%2]
        if (newSetValue == 0)
        {
            return false;
        }
        else if ((newSetValue > 0 && (SOCavg > 100000-SOCborder || SOCmax > 100000-SOCborder/2)) || (newSetValue < 0 && (SOCavg < SOCborder || SOCmin <SOCborder/2)))
        {
            return false;
        }
        else 
        {
            return true;
        }
    }
    
    function cancelContract() external onlyContractor onlyOnePerBlock
    {
        if (AdrBalance[msg.sender]>2*PricePerBlock) //period of notice of 2 blocks
        {
            uint bal = AdrBalance[msg.sender];
            AdrBalance[msg.sender] = 2*PricePerBlock;
            msg.sender.transfer(bal-2*PricePerBlock);
        }
        else
        {
            revert("try hardCancelContract");
        }
    }
    
    function hardCancelContract() external onlyContractor onlyOnePerBlock
    {
        if (AdrBalance[msg.sender]<=2*PricePerBlock) //no flexibility left in ESSs ...
        {
            uint bal = AdrBalance[msg.sender];
            AdrBalance[msg.sender] = 0;
            msg.sender.transfer(bal);
            setPoint[0] = 0;
            setPoint[1] = 0;
            contractor = nobody;
            PricePerBlock = 0;
        }
        else
        {
            revert("");
        }
    }
    
    function endOfContract() internal
    {
        setPoint[block.number%2] = 0;
        if (setPoint[0]==0&&setPoint[1]==0)//&&setPoint[2]==0)
        {
            contractor = nobody;
            PricePerBlock = 0;
        }
    }
    
    function voteForNewPrice(uint32 newPrice) external onlyNotUnderContract onlyRegistered
    {
        price = newPrice; //TODO implement voting
    }
    
    function getReward() external notContractor
    {
        uint myReward = AdrBalance[msg.sender];
        AdrBalance[msg.sender] = 0;
        msg.sender.transfer(myReward);
    }
    
    function getReward(uint myReward) external notContractor
    {
        if (AdrBalance[msg.sender]>=myReward)
        {
            AdrBalance[msg.sender] -= myReward;
            msg.sender.transfer(myReward);
        }
        else
        {
            revert("invalid reward");
        }
    }
    
    //registration/deregistration
    function register(uint32 PoptCh_i, uint32 PoptDch_i, uint32 _Pmax, uint24 _SOC, int32 _Pres) external payable onlyNonregistered notContractor onlyNotUnderContract onlyOnePerBlock
    {
        require(_Pmax>PoptCh_i&&_Pmax>PoptDch_i&&_Pmax<10000000000000,"invalid Pmax");
        registered[msg.sender] = true;
        RegisteredAddresses[numberOfAdresses] = msg.sender;
        RegistrationIndex[msg.sender] = numberOfAdresses++;
        setPoptCh(PoptCh_i);
        setPoptDch(PoptDch_i);
        setSOC(_SOC);
        setPres(_Pres);
        Pmax[msg.sender]=_Pmax;
        AdrBalance[msg.sender] += msg.value;
        updatePmaxTot();
        //active[msg.sender] = 13;
    }
    
    function deregister() external onlyRegistered
    {
        registered[msg.sender] = false;
        SOC[msg.sender] = 0;
        Pres[msg.sender] = 0;
        PoptCh[msg.sender] = 0;
        PoptDch[msg.sender] = 0;
        Pmax[msg.sender] = 0;
        RegisteredAddresses[RegistrationIndex[msg.sender]] = RegisteredAddresses[numberOfAdresses-1];
        RegistrationIndex[RegisteredAddresses[numberOfAdresses-1]] = RegistrationIndex[msg.sender];
        RegisteredAddresses[numberOfAdresses-1] = 0;
        RegistrationIndex[msg.sender] = 0;
        numberOfAdresses--;
        updatePmaxTot();
        //active[msg.sender] = 0;
    }
    
    function deregister(address _a) internal 
    {
        registered[_a] = false;
        SOC[_a] = 0;
        Pres[_a] = 0;
        PoptCh[_a] = 0;
        PoptDch[_a] = 0;
        Pmax[_a] = 0;
        RegisteredAddresses[RegistrationIndex[_a]] = RegisteredAddresses[numberOfAdresses-1];
        RegistrationIndex[RegisteredAddresses[numberOfAdresses-1]] = RegistrationIndex[_a];
        RegisteredAddresses[numberOfAdresses-1] = 0;
        RegistrationIndex[_a] = 0;
        numberOfAdresses--;
        updatePmaxTot();
        //active[_a] = 0;
    }

    function updatePmaxTot() internal
    {
        PmaxTot = 0;
        for (uint24 i = 0; i < numberOfAdresses; i++)
        {
            if (Pmax[RegisteredAddresses[i]] > PmaxTot)
            {
                PmaxTot = Pmax[RegisteredAddresses[i]];
            }
        }
    }
    
    //automatic recognation of offline neighbors TODO rewrite with LastActiveBlock
    function checkNeighbors() internal 
    {
        if (numberOfAdresses>1)
        {
            int32 n = int32(RegistrationIndex[msg.sender])-1;
            if (n == -1)
            {
                n = int32(numberOfAdresses)-1;
            }
            if (LastActiveBlock[RegisteredAddresses[uint24(n)]]<block.number-2 || AdrBalance[RegisteredAddresses[uint24(n)]]<price * 2 * PmaxTot) //deregister if inactive during the last 2 blocks //if(--active[RegisteredAddresses[uint(n)]]<0)
            {
                deregister(RegisteredAddresses[uint24(n)]);
            }
        }
    }
    
    //setters
    function setState(uint24 newSOC, int32 newPres, int32 oldInstruction, int32 oldBatOp) external onlyRegistered onlyOnePerBlock
    {
        if (newPres>=0)
        {
            require(newPres<int(Pmax[msg.sender]),"invalid Pres");
        }
        else
        {
            require(newPres>-int(Pmax[msg.sender]),"invalid Pres");
        }
        setSOC(newSOC);
        checkNeighbors();
        // if contracted => check and get paid 
        if (contractor!=nobody)
        {
            // did what supposed to do
            if (setPoint[(block.number-1)%2]!=0)
            {
                if (oldInstruction==oldBatOp||(oldBatOp>0&&oldInstruction<oldBatOp)||(oldBatOp<0&&oldInstruction>oldBatOp)) //Belohnung auch bei Übererfüllung der Flexibilität  
                {
                    uint reward = 0;
                    //all zero -> uniform distribution
                    if (setPoint[(block.number-1)%2]==PresTot[(block.number - 1)%2])
                    {
                        reward = uint(PricePerBlock/numberOfAdresses);
                    }
                    else
                    {
                        //reward = uint(PricePerBlock/numberOfAdresses); //first simple approach --> better approach needed
                        reward = uint((int(PricePerBlock)*oldInstruction)/(PresTot[(block.number - 1)%2]-setPoint[(block.number-1)%2]));
                        
                        //no reward >PricePerBlock
                        if (reward > PricePerBlock)
                        {
                            reward = PricePerBlock;
                        }
                    }
                    //ensure there´s no overflow
                    if (AdrBalance[contractor]>=reward)
                    {
                        AdrBalance[contractor] -= reward;
                        AdrBalance[msg.sender] += reward;
                    }
                    else
                    {
                        AdrBalance[msg.sender] += AdrBalance[contractor];
                        AdrBalance[contractor] = 0;
                    }
                }
                /*else
                {
                    //TODO: optionally implement partial payout
                }*/
            }
            
            //check if enough balance to continue contract //TODO bugfix: right now following peers are no longer paid...
            if (AdrBalance[contractor]<PricePerBlock)
            {
                endOfContract();
            }
            else if (setPoint[(block.number-1)%2]!=0&&setPoint[(block.number-1)%2]!=setPoint[block.number%2])
            {
                setPoint[block.number%2] = setPoint[(block.number-1)%2];
            }
            if (!flexibilityAvailable(setPoint[(block.number)%2],5000))
            {
                endOfContract();
            }   
        }
        else
        {
            //if not contracted get paid / pay within community
            if (oldInstruction==oldBatOp && flexibilityAvailable(-1, 1000) && flexibilityAvailable(1, 1000) && numberOfAdresses > 1)
            {
                //get paid for difference btw. own residual load and battery operation
                uint communityreward = uint(oldBatOp - Pres[msg.sender] + int(PmaxTot)) * price_internal / (numberOfAdresses - 1);
                for (uint24 i=0; i<numberOfAdresses; i++)
                {
                    if (RegisteredAddresses[i]!=msg.sender)
                    {    
                        if (AdrBalance[RegisteredAddresses[i]]>=communityreward)
                        {
                            AdrBalance[RegisteredAddresses[i]] -= communityreward;
                            AdrBalance[msg.sender] += communityreward;
                        }
                        else
                        {
                            AdrBalance[msg.sender] += AdrBalance[RegisteredAddresses[i]];
                            AdrBalance[RegisteredAddresses[i]] = 0;
                        }
                    }
                }

                /*if (oldBatOp>Pres[msg.sender]) //still use old Pres here
                {
                    uint communityreward = uint(oldBatOp - Pres[msg.sender] + int(PmaxTot)) * price;

                }*/

            }
        }

        setPres(newPres);       
    }
    
    function setSOC(uint24 _newvalue) internal
    {
        SOC[msg.sender] = _newvalue;
    }
    
    function setPres(int32 _newvalue) internal //Consumer counting arrow system
    {
        if (block.number > BlockCounterNewBlock)
        {
            BlockCounterNewBlock = uint32(block.number);
            PresTot[block.number%2] = 0;
        }
        PresTot[block.number%2] += _newvalue;
        Pres[msg.sender] = _newvalue;
    }
    
    function setPoptCh(uint32 _newvalue) public onlyRegistered //only at registration / if updated
    {
        PoptCh[msg.sender] = _newvalue;
    }
    
    function setPoptDch(uint32 _newvalue) public onlyRegistered //only at registration / if updated
    {
        PoptDch[msg.sender] = _newvalue;
    }
    
    //getter
    
    function isContracted() external view returns (bool)
    {
        if (contractor != nobody)
        {
            return true;
        }
        else 
        {
            return false;
        }
    }
    
    function readInstruction() external onlyRegistered view returns (int)
    {
        return readInstruction(msg.sender);
    }

    
    function readInstruction(address _a) internal view returns (int) 
    {  
        //get total residual load in respect to setPoint
        int PresTotal = PresTot[(block.number)%2]-setPoint[(block.number)%2]; //old : PresTotal-=setPoint; blocknuber - 1 because although it is a call, block.number is already the number of the next (future) block...
        
        //instruction for _a
        int returnValue = 0;

        //counter of optimal operation points of active ESSs
        uint PoptTotal = 0;
        
        //sort depending on SOC
        uint24[] memory Order = new uint24[](numberOfAdresses);
        uint24[] memory Pos = new uint24[](numberOfAdresses);
        for (uint24 i = 0; i<numberOfAdresses; i++)
        {
            Pos[i] = SOC[RegisteredAddresses[i]];
        }
        Pos = getPos(Pos);
        Order = getOrder(Pos);	
        
        //index of last active ESS 
        uint LastOne = Order[numberOfAdresses-1];
        
        //start allocation of power
        //case 1: positive residual load --> discharge ESSs
        if (PresTotal>0)
        {
            for (i = 0; i<numberOfAdresses; i++)
            {   
                //add up optimal operation points for charging from high to low SOC
                PoptTotal += PoptDch[RegisteredAddresses[Order[i]]];
                
                //stop if total residial load is reached
                if (PoptTotal >= uint(PresTotal))
                {
                    //choose the index which is closer 
                    if ((PoptTotal-PoptDch[RegisteredAddresses[Order[i]]])/2<uint(PresTotal)||i==0)
                    {
                        //i is closest
                        LastOne = Order[i];
                    }
                    else
                    {
                        //i-1 is closest
                        LastOne = Order[i-1];
                        PoptTotal -= PoptDch[RegisteredAddresses[Order[i]]];
                    }
                    break;
                }
            }
            if (LastOne==Order[numberOfAdresses-1])
            {
                //all ESSs are active --> use adapted optimal operation points
                returnValue = int(PoptDch[_a]*uint(PresTotal)/PoptTotal);
            }
            else
            {
                //only parts are active
                if (Pos[RegistrationIndex[_a]]<=Pos[LastOne])//(SOC[_a]>SOC[RegisteredAddresses[LastOne]]||_a==RegisteredAddresses[LastOne])
                {
                    //_a active
                    returnValue = int(PoptDch[_a]*uint(PresTotal)/PoptTotal);
                }
                else
                {
                    //_a inactive
                    returnValue = 0;
                }
            }
        }
        //case 2: no residial load --> nothing to do
        else if (PresTotal==0)
        {
            returnValue = 0;
        }	
        //case 3: negative load --> charge 
        else
        {
            //index of last active ESS 
            LastOne = Order[0];
            for (i = 0; i<numberOfAdresses; i++)
            {
                //add up optimal charging points from low to high SOC
                PoptTotal += PoptCh[RegisteredAddresses[Order[numberOfAdresses-1-i]]];
                
                //stop if total residial load is reached
                if (PoptTotal >= uint(-PresTotal))
                {
                    //choose the index which is closer 
                    if ((PoptTotal-PoptCh[RegisteredAddresses[Order[numberOfAdresses-1-i]]])/2<uint(-PresTotal)||i==0)
                    {
                        //i is closest
                        LastOne = Order[numberOfAdresses-1-i];
                    }
                    else
                    {
                        //i-1 is closest
                        LastOne = Order[numberOfAdresses-i];
                        PoptTotal -= PoptCh[RegisteredAddresses[Order[numberOfAdresses-1-i]]];
                    }
                    break;
                }
            }
            if (LastOne==Order[0])
            {
                //all ESSs are active --> use adapted optimal operation points
                returnValue = -int(PoptCh[_a]*uint(-PresTotal)/PoptTotal); //todo add charging / discharging missing maximum/minimum!!
            }
            else
            {
                //only parts are active
                if (Pos[RegistrationIndex[_a]]>=Pos[LastOne])//(SOC[_a]<SOC[RegisteredAddresses[LastOne]]||_a==RegisteredAddresses[LastOne]) //(LastOne>=RegistrationIndex[_a])//todo zero or close to Popt depending on index
                {
                    //_a active
                    returnValue = -int(PoptCh[_a]*uint(-PresTotal)/PoptTotal);
                }
                else
                {
                    //_a inactive 
                    returnValue = 0;
                }
            }
        }
        return returnValue;
    }
    
    function getPos(uint24[] memory data) public pure returns (uint24[] memory) {

        uint n = data.length;
        uint24[] memory arr = new uint24[](n);
        uint24 i;
        uint24 j;

        for(i = 0; i<n; i++) {
            arr[i] = 0;
            for(j = 0; j<n; j++)
            {
                if(data[i]<data[j]||(data[i]==data[j]&&j<i))
                {
                    arr[i]++;
                }
            }
        }
        return arr;
    }

    function getOrder(uint24[] memory data) internal pure returns (uint24[] memory) {
      
        uint n = data.length;
        uint24[] memory arr = new uint24[](n);
        //uint[] memory temp = new uint[](n);
        uint24 i;
        uint24 j;
        //temp = getPos(data);
        for(i = 0; i<n; i++)
        {  
            for(j = 0; j<n; j++)
            {
                if(i==data[j])
                {
                    arr[i] = j;
                }
            }
        }
        return arr;
    }
}
