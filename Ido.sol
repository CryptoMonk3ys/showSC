// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IvNFT.sol";
import "./IStake.sol"; //interfaz
import "./ISwap.sol"; //interfaz

contract Ido is Ownable{

    using SafeMath for uint;
    address public usdt;
    address public vsion;
    uint public limitPublicInf; //limite inferior de inversion publica
    uint public factorPublic; //limite superior de inversion publica
    uint public limitPrivateInf; //limite inferior de inversion privada
    uint public factorPrivate; //limite superior de inversion privada
    uint private decUSDT; // decimales USDT
    uint private decVsion; // decimales Vsion
    IvNFT vip;    
    uint limit_level;
    mapping (address => bool) public stake;    
    ISwap pair; 

    constructor(address _usdt,address _vsion,address _stake1,address _stake2,address _stake3, address _pair) {        
        usdt=_usdt;
        vsion=_vsion;
        pair=ISwap(_pair);
        stake[_stake1]=true;
        stake[_stake2]=true;
        stake[_stake3]=true;
        decUSDT=(10**IERC20Metadata(usdt).decimals());
        decVsion=(10**IERC20Metadata(vsion).decimals());
        limitPublicInf=decUSDT.mul(10);
        factorPublic=3;
        limitPrivateInf=decUSDT.mul(100);
        factorPrivate=decUSDT.mul(10000);
    }

    event PublicSales(
        address _holder,
        address _addressProjectData,
        address _token,
        uint256 _tokenSales,
        uint256 _USDTSpent
    );

    event PrivateSales(
        address _holder,
        address _addressProjectData,
        address _token,
        uint256 _tokenSales,
        uint256 _USDTSpent
    );

    event WithdrawProject(        
        address _addressProjectData,
        address _token,
        uint256 _USDT
    );

    event WithdrawHolderPublic(        
        address _addressHolder,
        address _token,
        uint256 _amountToken
    );

    event WithdrawHolderPrivate(        
        address _addressHolder,
        address _token,
        uint256 _amountToken
    );

    event WithdrawNFT(        
        address _addressHolder,
        uint256 _level,
        uint256 _amountPrice
    );

    event newProject(        
        address _addressProject,
        uint timeInit,
        address _addressToken,
        uint256 _pricePrivate,
        uint256 _pricePublic
    );

    struct project{        
        uint pricePrivate; // precio privado 
        uint pricePublic; // precio publico
        uint tokenPrivate;
        uint tokenPublic;
        address adToken;        
        uint timeSalePrivate; // inicio privado
        uint timeSalePublic; // inicio publico
        uint timeClaim;// fin de toda venta
        uint amount; // USDT: DINERO DEL PROYECTO
        uint countPublic; 
        uint countPrivate;
    }  

    struct investment {
        uint pubTokens; // TOKENS COMPRADOS
        uint publAmount; // contador de monto personal publico
        uint timePublic;   
        uint privTokens;
        uint privAmount; // contador de monto personal privado
        uint forClaimVesting; // TOKENS POR RECLAMAR PRIVADO
        uint timePrivate;
    }    
    
    mapping(address => mapping (address => investment)) public holder; // HOLDER // PROYECTO // INVERSION    
    mapping(address => project) public Project;
    mapping(address => bool) public permit;
    
    // debe haber precio privado y precio publico
    function setProject(address _project, address _token,
    uint _pricePrivate,uint _pricePublic, uint _tokenPrivate,uint _tokenPublic, 
    uint _time1,uint _time2,uint _time3) public onlyOwner {// 3 variables para los 3 tiempos
        require(!permit[_token],"This token is not allowed in the IDO");
        require(!permit[_project],"Project already registered");
        require(IERC20(_token).balanceOf(address(this))>=_tokenPrivate.add(_tokenPublic),"No founds");
        permit[_token]=true;
        permit[_project]=true;
        uint _actual=block.timestamp;            
        Project[_project]=project(_pricePrivate,_pricePublic,_tokenPrivate // se envian convertido
        ,_tokenPublic
        ,_token
        ,_time1,
        _time2,
        _time3,
        0,
        0,
        0);  // depende del proyecto 
        emit newProject( _project,_actual, _token, _pricePrivate, _pricePublic );    
    }

    function setPermit(address _token) public onlyOwner{
        require(_token !=address(0),"Wrong address");
        permit[_token]=false;
    }

    function setPair(address _par) public onlyOwner{
        require(_par !=address(0),"Wrong address");
        pair=ISwap(_par);
    }

    function setStake(address _stake)public onlyOwner{
        require(_stake !=address(0),"Wrong address");
        stake[_stake]= true;
    }    
    
    function getAddressToken(address _project)private view returns(address){
        return Project[_project].adToken;
    }    

    function getPricePrivate(address _project) private view returns (uint){
        return Project[_project].pricePrivate;
    }

    function getPricePublic(address _project) private view returns (uint){
        return Project[_project].pricePublic;
    }

    function getTokensPrivate(address _project) private view returns (uint){
        return Project[_project].tokenPrivate;
    }

    function getTokensPublic(address _project) private view returns (uint){
        return Project[_project].tokenPublic;
    }

    function getTimeStaking(address _holder, address _stake) private view returns(uint){
        IStake staking= IStake(_stake);
        (,,,uint256 _fin)=staking.userInfo(_holder);
        if (_fin!=0){
            _fin=_fin.sub(block.timestamp);           
        }
        else{
            _fin=0;
        }
        return _fin.div(365).div(1 days); // minutos para tesnet
    }

    function getStaking(address _holder, address _stake) private view returns(uint){
        IStake staking= IStake(_stake);
        (uint256 _staking,,,)=staking.userInfo(_holder);
        _staking=_staking.mul(ISwap(pair).GetPriceVsion()).div(decVsion);
        return _staking;
    }        

    function getAmountPublic(address _holder, address _project) external view returns(uint){
        return holder[_holder][_project].pubTokens;
    }

    function getAmountPrivate(address _holder, address _project)external view returns(uint){
        return holder[_holder][_project].privTokens;
    }    

    function setLimitLevel(uint _limitLevel)public onlyOwner{ // nivel minimo de NFT
        limit_level=_limitLevel;
    }
    
    function setLimitPublicInf(uint _limit)public onlyOwner{ 
        limitPublicInf=_limit.mul(decUSDT); // solo poner la cantidad normal
    }

    function setLimitPrivateInf(uint _limit)public onlyOwner{ 
        limitPrivateInf=_limit.mul(decUSDT); // solo poner la cantidad normal
    }

    function setFactorPublicSup(uint _factor)public onlyOwner{
        factorPublic=_factor; // solo poner la cantidad normal
    }

    function setFactorPrivateSup(uint _amount)public onlyOwner{ 
        factorPrivate=_amount.mul(decUSDT); // solo poner la cantidad normal
    }

    function setVip(address _nft)public onlyOwner{
        require(_nft !=address(0),"Wrong address");
        vip=IvNFT(_nft);
    }

    // INTERFAZ PARA JALAR VARIABLES MAPPING DE OTRO CONTRATO
    
    function investPrivate(address _project, address _staking, uint _amount)external{  // falta verificar el contador personal      
        // USAR DIRECTAMENTE //CONTEXT ---LIBRERIA msg.sender global
        require(stake[_staking],"wrong staking address");
        project storage proyecto=Project[_project];
        require(proyecto.timeSalePublic>=block.timestamp,"private sale has expired");
        require(block.timestamp>=proyecto.timeSalePrivate,"Private sale not activated");        
        require(getTimeStaking(msg.sender,_staking)>=1,"Insufficient staking time");
        require(IERC20Metadata(usdt).balanceOf(msg.sender)>= _amount,"Insufficient usdt" );
        require(getStaking(msg.sender,_staking)>limitPrivateInf,"Insufficient staking"); // verificando limite inferior
        uint _nft=IvNFT(vip).balanceOf(msg.sender);
        require(_nft>0,"You are not a vip member");
        require(_amount <= _nft*factorPrivate,"Investment limit exceeded"); // verificando limite superior
        // VERIFICANDO LIMITE PERSONAL DE INVERSION PRIVADA
        investment storage Holder=holder[msg.sender][_project];
        require(Holder.privAmount+_amount<=_nft*factorPrivate,"with the amount entered exceeds your investment limit in the private sale");    
        address _adToken=getAddressToken(_project);        
        uint _tokens=_amount.mul(10**IERC20Metadata(_adToken).decimals()).div(getPricePrivate(_project));       
        require(proyecto.countPrivate.add(_tokens)<=getTokensPrivate(_project),"the amount exceeds the token stock limit");
         
        Holder.privTokens+=_tokens;
        Holder.forClaimVesting+=_tokens;
        proyecto.amount+=_amount;
        Holder.privAmount+=_amount;
        proyecto.countPrivate+=_tokens;
        Holder.timePrivate=block.timestamp;
        collectStaker(_amount);
        emit PrivateSales(msg.sender,_project,_adToken,_amount,_tokens);
    } 

    function investPublic(address _project, address _stake, uint _amount)external{        
        // USAR DIRECTAMENTE //CONTEXT ---LIBRERIA msg.sender global
        require(stake[_stake],"wrong staking address");
        project storage proyecto=Project[_project];
        require(proyecto.timeClaim>=block.timestamp,"Public sale has expired");
        require(block.timestamp>proyecto.timeSalePublic,"Public sale not activated");
        require(IERC20Metadata(usdt).balanceOf(msg.sender)>= _amount,"Insufficient usdt" );        
        uint _staking=getStaking(msg.sender,_stake);
        // VERIFICANDO LIMITE PERSONAL DE INVERSION PUBLICA
        investment storage Holder=holder[msg.sender][_project];
        require(Holder.publAmount+_amount<=_staking.mul(factorPublic),"with the amount entered exceeds your investment limit in the public sale");
        require(_staking>limitPublicInf,"Insufficient staking"); // verificando limite inferior
        require(_amount <= _staking.mul(factorPublic),"Investment limit exceeded"); // verificando limite superior
        address _adToken=getAddressToken(_project);        
        uint _tokens=_amount.mul(10**IERC20Metadata(_adToken).decimals()).div(getPricePublic(_project));        
        require(proyecto.countPublic.add(_tokens)<=getTokensPublic(_project),"the amount exceeds the token stock limit");
           
        Holder.pubTokens+=_tokens; 
        proyecto.amount+=_amount;
        Holder.publAmount+=_amount;
        proyecto.countPublic+=_tokens;
        Holder.timePublic=block.timestamp;
        collectStaker(_amount);
        emit PublicSales(msg.sender, _project, _adToken, _amount, _tokens );
    }   

    function collectStaker( uint256 _amount) private {         
        IERC20(usdt).transferFrom(msg.sender,address(this),_amount);
    }
    
    function ClaimProject() external {   
        project storage proyecto=Project[msg.sender];
        require(block.timestamp>=proyecto.timeClaim,"It's not time to retire yet");
        require(proyecto.amount>0,"The project has no funds");              
        uint _amount=proyecto.amount;
        proyecto.amount=0;
        IERC20Metadata(usdt).transfer(msg.sender,_amount);
        emit WithdrawProject(msg.sender, usdt, _amount );
    }    

    function ClaimPublic(address _project) external {
        investment storage Holder=holder[msg.sender][_project];       
        require(block.timestamp>=Holder.timePublic.add(30 days),"It's not time to retire yet");
        require(Holder.pubTokens>0,"you have no funds");
        uint _amount=Holder.pubTokens;
        address _token = getAddressToken(_project);
        Holder.pubTokens=0;
        IERC20Metadata(_token).transfer(msg.sender,_amount);
        emit WithdrawHolderPublic(msg.sender,_token,_amount);
    }

    function ClaimVesting(address _project) external {
        investment storage Holder=holder[msg.sender][_project]; 
        uint _factor=block.timestamp.sub(Holder.timePrivate).div(30 days);
        //_factor=1; 
        require(_factor>0,"It's not time to retire yet");
        require(Holder.privTokens>0,"You have no founds");
        Holder.timePrivate+= _factor.mul(30 days) ; // tiempo+= 30 days * factor 
        address _token = getAddressToken(_project);
        uint _amount=Holder.privTokens.div(10).mul(_factor);        
        Holder.forClaimVesting-=_amount;        
        IERC20Metadata(_token).transfer(msg.sender,_amount);
        emit WithdrawHolderPrivate(msg.sender,_token,_amount);
    }

    function buyNFT( uint _level)external{
        uint _price=IvNFT(vip).getPrice(_level);
        require(_level>=limit_level,"Increase your NFT level to participate");
        require(_price>0,"Wrong level");
        require(IERC20Metadata(usdt).balanceOf(msg.sender)>= _price,"Insufficient usdt" );
        _price=_price.mul(decUSDT);
        IvNFT(vip).safeMint(msg.sender,_level);
        IERC20(usdt).transferFrom(msg.sender,address(this),_price);
        emit WithdrawNFT(msg.sender,_level,_price);
    }
}