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
    templateUrl: './error.html'
})
export class ErrorComponent implements OnInit, OnDestroy {


    constructor(public router: Router, public route: ActivatedRoute,
                public userService: UserLoginService, private http: Http) {

        console.log("Invite error page initialised.");
        
    }

    ngOnInit() {

    }

    ngOnDestroy() {

    }

}