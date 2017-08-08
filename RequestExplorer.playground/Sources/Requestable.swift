import Foundation

public enum RequestableError: Error {
    case invalidURL
    case timeout
    case onlyHTTPResponsesSupported
}

public enum Result<T> {
    case success(T)
    case failure(Error)
    
    public var error: Error? {
        switch self {
        case .failure(let error): return error
        case .success(_): return nil
        }
    }
    
    public var response: T? {
        switch self {
        case .failure(_): return nil
        case .success(let response): return response
        }
    }
}

public struct Response<T: DataInitializable> {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: T?
}

public protocol DataInitializable { }

public protocol DataThrowingInitializable: DataInitializable {
    init(data: Data) throws
}

public protocol DataFailingInitializable: DataInitializable {
    init?(data: Data)
}

public protocol Requestable {
    func request() throws -> URLRequest
    func fetch<T: DataThrowingInitializable>(via session: URLSession) -> Result<Response<T>>
    func fetch<T: DataFailingInitializable>(via session: URLSession) -> Result<Response<T>>
}

public typealias EmptyResponse = Response<Data>

extension Data: DataFailingInitializable {
    public init?(data: Data) {
        self = data
    }
}

extension JSONNode: DataThrowingInitializable { }

public enum ConvertableError: Swift.Error {
    case couldNotInferConversionType
    case couldNotConvertFromData
}

extension Requestable {
    
    public func fetch<T: DataThrowingInitializable>(via session: URLSession = .shared) -> Result<Response<T>> {
        
        do {
            let request = try self.request()
            
            var result: Result<Response<T>>?
            
            session.dataTask(with: request) { (data, response, errpr) in
                
                switch (data, response, errpr) {
                    
                case (_, _, let error?):
                    result = Result.failure(error)
                    
                case (nil, let response as HTTPURLResponse, nil):
                    let urlResponse = Response<T>(statusCode: response.statusCode,
                                                  headers: response.allHeaderFields as! [String: String],
                                                  body: nil)
                    result = Result.success(urlResponse)
                    
                case (let data?, let response as HTTPURLResponse, nil):
                    do {
                        let body = try T(data: data)
                        let urlResponse = Response<T>(statusCode: response.statusCode,
                                                      headers: response.allHeaderFields as! [String: String],
                                                      body: body)
                        result = Result.success(urlResponse)
                    } catch {
                        result = Result.failure(error)
                    }
                    
                case (_, _, nil):
                    result = Result.failure(RequestableError.onlyHTTPResponsesSupported)
                }
                
                }.resume()
            
            while result == nil {
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
            
            return result!
            
        } catch {
            return Result.failure(error)
        }
    }
    
    public func fetch<T: DataFailingInitializable>(via session: URLSession = .shared) -> Result<Response<T>> {
        
        do {
            let request = try self.request()
            
            var result: Result<Response<T>>?
            
            session.dataTask(with: request) { (data, response, errpr) in
                
                switch (data, response, errpr) {
                    
                case (_, _, let error?):
                    result = Result.failure(error)
                    
                case (nil, let response as HTTPURLResponse, nil):
                    let urlResponse = Response<T>(statusCode: response.statusCode,
                                                  headers: response.allHeaderFields as! [String: String],
                                                  body: nil)
                    result = Result.success(urlResponse)
                    
                case (let data?, let response as HTTPURLResponse, nil):
                    if let body = T(data: data) {
                        let urlResponse = Response<T>(statusCode: response.statusCode,
                                                      headers: response.allHeaderFields as! [String: String],
                                                      body: body)
                        result = Result.success(urlResponse)
                    } else {
                        result = Result.failure(ConvertableError.couldNotConvertFromData)
                    }
                    
                case (_, _, nil):
                    result = Result.failure(RequestableError.onlyHTTPResponsesSupported)
                }
                
                }.resume()
            
            while result == nil {
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
            
            return result!
            
        } catch {
            return Result.failure(error)
        }
    }
}

extension URLRequest: Requestable {
    public func request() throws -> URLRequest {
        return self
    }
}

extension URL: Requestable {
    public func request() throws -> URLRequest {
        return URLRequest(url: self)
    }
}

extension String: Requestable {
    public func request() throws -> URLRequest {
        if let url = URL(string: self) {
            return try url.request()
        } else {
            throw RequestableError.invalidURL
        }
    }
}
