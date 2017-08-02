import UIKit
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

public enum Result<A> {
    case success(A)
    case error(Error)
}

public enum HttpMethod {
    case get
    case post(data: Data)
    case put (data: Data)
    case delete
    
    public var name: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .put: return "PUT"
        case .delete: return "DELETE"
        }
    }
}

extension Result {
    public init(_ value: A?, or error: Error) {
        if let value = value {
            self = .success(value)
        } else {
            self = .error(error)
        }
    }
    
    public var value: A? {
        guard case .success(let v) = self else { return nil }
        return v
    }
}


public struct Resource<A : Codable> {
    var url : URL
    var parse: (Data) -> A? = { data in
        try? JSONDecoder().decode(A.self, from: data)
    }
    var method: HttpMethod = .get
}

extension Resource {
    init(url: URL, method: HttpMethod = .get) {
        self.url = url
        self.method = method
    }
}

//custom errors
public enum WebserviceError: Error {
    case notAuthenticated
    case badInput
    case other
}

//custom configure urlsession
var session: URLSession {
    let config = URLSessionConfiguration.default
    return URLSession(configuration: config)
}

public final class Webservice {
    public var authenticationToken: String?
    public init() { }
    
    public func load<A>(_ resource: Resource<A>, completion: @escaping (Result<A>) -> ()) {
        var req = URLRequest(url: resource.url)
        req.httpMethod = resource.method.name
        if case let .post(data) = resource.method {
            req.httpBody = data
        }
        
        session.dataTask(with: req, completionHandler: { data, response, error in
            let result: Result<A>
            if let _ = error {
                result = Result.error(WebserviceError.badInput)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                result = Result.error(WebserviceError.notAuthenticated)
            } else {
                let parsed = data.flatMap(resource.parse)
                result = Result(parsed, or: WebserviceError.other)
            }
            //This for playground only
            DispatchQueue.main.async {
                completion(result)
            }
        }) .resume()
    }
}

//Using http://jsonplaceholder.typicode.com for all type of requests
//Todos Model
struct Todos : Codable {
    let userId : Int
    let id : Int
    let title : String
    let completed : Bool
}

//Get
let url1 = URL(string:"http://jsonplaceholder.typicode.com/todos")!
let allTodos = Resource<[Todos]>(url : url1)

Webservice().load(allTodos) { (result) in
    
    if let todos = result.value {
        for todo in todos as [Todos] {
            print(todo)
        }
    }
}


//Post
struct Item : Codable {
    let userId : Int
    let body : String
    let title : String
}

struct Response : Codable {
    let id : Int
}

let item = Item(userId: 1, body: "foo1", title: "bar1")
let data = try! JSONEncoder().encode(item)

let res : Resource<Response> = Resource(
    url: URL(string:"http://jsonplaceholder.typicode.com/posts")!,
    method: .post(data: data)
)

Webservice().load(res) { results in
    if let response = results.value {
        print(response.id)
    }
}

//PUT
struct Item1 : Codable {
    let userId : Int
    let body : String
    let title : String
    let id : Int
}

let item1 = Item1(userId: 1, body: "foo1", title: "bar1", id : 1)
let data1 = try! JSONEncoder().encode(item1)

let res1 : Resource<Response> = Resource(
    url: URL(string:"http://jsonplaceholder.typicode.com/posts/1")!,
    method: .put(data: data1)
)

Webservice().load(res1) { results in
    if let response = results.value {
        print(response.id)
    }
}

//DELETE
let res2 : Resource<Response> = Resource(
    url: URL(string:"http://jsonplaceholder.typicode.com/posts/1")!,
    method: .delete
)

Webservice().load(res2) { results in
    guard let val = results.value else {
        return
    }
    print(val)
    PlaygroundPage.current.needsIndefiniteExecution = false
}


