//
//  DisplayListProtocol.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
//

enum DisplayListError: Error {
    case notImplemented
    case storedLinks(LinkRepositoryError)
    case serverError(LinkServerAPIError)
    case invalidRequestURL
    case httpStatus(Int)
    case emptyData
    case invalidMime(String?)
}

protocol DisplayListProtocol {
    @MainActor
    func loadAllDisplayLinksStream() -> AsyncThrowingStream<DisplayLink, Error>
}
