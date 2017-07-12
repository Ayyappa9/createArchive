import {Component, OnDestroy, OnInit} from "@angular/core";
import {ActivatedRoute, Router} from "@angular/router";
import {UserLoginService} from "../../../service/user-login.service";
import {CognitoCallback} from "../../../service/cognito.service";
import {Http, Response, URLSearchParams, Headers, RequestOptions} from "@angular/http";
import "rxjs/add/operator/map";
import { Observable } from 'rxjs/Observable';
import 'rxjs/Rx';



@Component({
    selector: 'awscognito-angular2-app',
    templateUrl: './invite.html'
})
export class InviteComponent implements CognitoCallback, OnInit, OnDestroy {

    mobileNumber: string;
    inviteCode: string;
    fromCustomerName: string;
    reqbody: {};
    errorMessage: string;
    private sub: any;
    data: any = {};

    private apiUrl =  'https://csd02dkd3i.execute-api.ap-northeast-1.amazonaws.com/testing/customer/invite?inviteCode=';

    constructor(public router: Router, public route: ActivatedRoute,
                public userService: UserLoginService, private http: Http) {
        console.log("Invite code url initialised.");
        
    }

    ngOnInit() {
        this.sub = this.route.params.subscribe(params => {
            this.inviteCode = params['inviteCode'];
            console.log("Invite code : "+this.inviteCode);
        });
        this.getCustomerName();
        //this.getCustomerData();
        this.errorMessage = null;
    }

    ngOnDestroy() {
        this.sub.unsubscribe();
    }

    onNext() {
        this.errorMessage = null;
        //this.userService.confirmNewPassword(this.email, this.verificationCode, this.password, this);
    }

    onDownload() {
        console.log("Download the tipp appilcation.");
        //this.get(this.apiUrl);
        this.reqbody = {
        "inviteCode": this.inviteCode,
        "toNumber": this.mobileNumber
        };
        //console.log(this.reqbody);
        this.apiUrl = "https://csd02dkd3i.execute-api.ap-northeast-1.amazonaws.com/testing/customer/invite";
        this.post(this.apiUrl,this.reqbody);
        //this.postUserName();
        //this.testRequest();
        //this.http.post(this.apiUrl, JSON.stringify(this.reqbody), this.getPutHeaders());
        
    }

    getCustomerData(){
        this.apiUrl = this.apiUrl + this.inviteCode;
        //console.log(this.apiUrl);
    	return this.http.get(this.apiUrl).map( (res:Response) => res.json())
    }

    getCustomerName(){
    	this.getCustomerData().subscribe(data => {
    	this.data = data;
        this.fromCustomerName = data.data.name;
        console.log("From Customer Name : "+this.fromCustomerName);
    	});
    }

    postUserData(){
        this.apiUrl = "https://csd02dkd3i.execute-api.ap-northeast-1.amazonaws.com/testing/customer/invite";
        console.log(this.apiUrl);
        this.reqbody = {
        "inviteCode": this.inviteCode,
        "toNumber": "9980691872"
        };
        return this.http.post(this.apiUrl,this.reqbody,{ }).map( (res:Response) => res.json())
    }

    postUserName(){
        console.log("Execute Post User Name");
        this.postUserData().subscribe(data => {
        this.data = data;
        //this.fromCustomerName = data.data.name;
        console.log("To Customer Data : "+this.data);
        });
    }

    get(url): Promise<any>
    {
        return this.http.get(url).map(response => {
            console.log(response.json());
            return response.json() || {success: false, message: "No response from server"};
        }).catch((error: Response | any) => {
            return Observable.throw(error.json());
        }).toPromise();
    }

    post(url, data): Promise<any>
    {
        //Config.baseUrl
        //console.log("Execute Post User Initiate");
        return this.http.post(url, data).map(response => {
            //console.log(response.json());
            this.router.ngOnDestroy();
            window.location.assign('http://tipp.co.in');
            return response.json() || {success: false, message: "No response from server"};
        }).catch((error: Response | any) => {
            return Observable.throw(error.json());
        }).toPromise();
    }

    testRequest() {
        var headers = new Headers();
        headers.append('content-type', 'application/json');
        this.apiUrl = "https://csd02dkd3i.execute-api.ap-northeast-1.amazonaws.com/testing/customer/invite";
        let data = new URLSearchParams();
        data.append('inviteCode', 'AddalaAVUgqO');
        data.append('toNumber', '9980691872');
        this.reqbody = {
        "inviteCode": this.inviteCode,
        "toNumber": "9980691872"
        };
            this.http
            .post('https://csd02dkd3i.execute-api.ap-northeast-1.amazonaws.com/testing/customer/invite', this.reqbody, {headers: headers})
            .subscribe(data => {
                alert(data);
            }, error => {
                console.log(error.json());
            });
    }

    cognitoCallback(message: string) {
        if (message != null) { //error
            this.errorMessage = message;
            console.log("result: " + this.errorMessage);
        } else { //success
            this.router.navigate(['/home/login']);
        }
    }

}