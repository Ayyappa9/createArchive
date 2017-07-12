import { Injectable } from '@angular/core';
import { Http } from '@angular/http';
//import { Config } from '../Config';
import { Observable } from 'rxjs/Observable';
import 'rxjs/Rx';

@Injectable()
export class Request {
	
	constructor(public http: Http)
	{
	
	}

	get(url): Promise<any>
	{
		//Config.baseUrl +
		return this.http.get(url).map(response => {
			return response.json() || {success: false, message: "No response from server"};
		}).catch((error: Response | any) => {
			return Observable.throw(error.json());
		}).toPromise();
	}

	post(url, data): Promise<any>
	{
		return this.http.post(url, data).map(response => {
			return response.json() || {success: false, message: "No response from server"};
		}).catch((error: Response | any) => {
			return Observable.throw(error.json());
		}).toPromise();
	}
}