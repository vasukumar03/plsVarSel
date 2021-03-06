#' @title Backward variable elimination PLS (BVE-PLS)
#'
#' @description A backward variable elimination procedure for elimination
#' of non informative variables.
#'
#' @param y vector of response values (\code{numeric} or \code{factor}).
#' @param X numeric predictor \code{matrix}.
#' @param ncomp integer number of components (default = 10).
#' @param ratio the proportion of the samples to use for calibration (default = 0.75).
#' @param VIP.threshold thresholding to remove non-important variables (default = 1).
#'
#' @details Variables are first sorted with respect to some importancemeasure, 
#' and usually one of the filter measures described above are used. Secondly, a 
#' threshold is used to eliminate a subset of the least informative variables. Then
#' a model is fitted again to the remaining variables and performance is measured. 
#' The procedure is repeated until maximum model performance is achieved.
#'
#' @return Returns a vector of variable numbers corresponding to the model 
#' having lowest prediction error.
#'
#' @author Tahir Mehmood, Kristian Hovde Liland, Solve Sæbø.
#'
#' @references I. Frank, Intermediate least squares regression method, Chemometrics and
#' Intelligent Laboratory Systems 1 (3) (1987) 233-242.
#'
#' @seealso \code{\link{VIP}} (SR/sMC/LW/RC), \code{\link{filterPLSR}}, \code{\link{shaving}}, 
#' \code{\link{stpls}}, \code{\link{truncation}},
#' \code{\link{bve_pls}}, \code{\link{ga_pls}}, \code{\link{ipw_pls}}, \code{\link{mcuve_pls}},
#' \code{\link{rep_pls}}, \code{\link{spa_pls}},
#' \code{\link{lda_from_pls}}, \code{\link{lda_from_pls_cv}}, \code{\link{setDA}}.
#' 
#' @examples
#' data(gasoline, package = "pls")
#' with( gasoline, bve_pls(octane, NIR) )
#'
#' @importFrom MASS lda
#' @export
bve_pls <- function( y, X, ncomp=10, ratio=0.75, VIP.threshold=1 ){
  modeltype <- "prediction"
  if (is.factor(y)) {
    modeltype <- "classification"
    y.orig <- as.numeric(y)
    y      <- model.matrix(~ y-1)
    tb     <- names(table(y.orig))
  } else {
    y <- as.matrix(y)
  }

  # Local variables
  nn <- dim( X )[1]
  pp <- dim( X )[2]
  # The elimination
  Z <- X
  terminated <- F
  Pg <- NULL
  K <- floor(nn*ratio) 
  if(modeltype == "prediction"){
    K    <- floor(nn*ratio)
    temp <- sample(nn)
    calk <- temp[1:K]      
    Zcal <- Z[calk, ];  ycal  <- y[calk,]  
    Ztest<- Z[-calk, ]; ytest <- y[-calk,] 
  } else 
    if(modeltype == "classification"){
      calK <- c() 
      for(jj in 1:length(tb)){
        temp <- sample(which(y.orig==tb[jj]))
        K    <- floor(length(temp)*ratio)
        calK <- c(calK, temp[1:K])
      }      
      Zcal  <- Z[calK, ];  ycal  <- y[calK,] 
      Ztest <- Z[-calK, ]; ytest <- y[-calK,] 
    }
  Variable.list <- list()
  is.selected   <- rep( T, pp )
  variables     <- which( is.selected ) 
  while( !terminated ){       
    # Fitting, and finding optimal number of components
    co <- min(ncomp, ncol(Zcal)-1)
    pls.object <- plsr(y ~ X,  ncomp=co, data = data.frame(y=I(ycal), X=I(Zcal)), validation = "LOO")
    if (modeltype == "prediction"){
      opt.comp <- which.min(pls.object$validation$PRESS[1,])
    } else if (modeltype == "classification"){
      classes <- lda_from_pls_cv(pls.object, Zcal, y.orig[calK], co)
      opt.comp <- which.max(colSums(classes==y.orig[calK]))
    }
    # Press      <- pls.object$valid$PRESS[1,]
    # opt.comp   <- which.min(Press)
    if(modeltype == "prediction"){
      mydata     <- data.frame( yy=c(ycal, ytest) ,ZZ=I(rbind(Zcal, Ztest)) , train= c(rep(TRUE, length(ycal)), rep(FALSE, length(ytest))))
    } else {
      mydata     <- data.frame( yy=I(rbind(ycal, ytest)) ,ZZ=I(rbind(Zcal, Ztest)) , train= c(rep(TRUE, length(y.orig[calK])), rep(FALSE, length(y.orig[-calK]))))
    }
    pls.fit    <- plsr(yy ~ ZZ, ncomp=opt.comp, data=mydata[mydata$train,])

    # Make predictions using the established PLS model 
    if (modeltype == "prediction"){
      pred.pls <- predict(pls.fit, ncomp = opt.comp, newdata=mydata[!mydata$train,])
      Pgi <- sqrt(sum((ytest-pred.pls[,,])^2))
    } else if(modeltype == "classification"){
      classes <- lda_from_pls(pls.fit,y.orig[calK],Ztest,opt.comp)[,opt.comp]
      Pgi       <- 100-sum(y.orig[-calK] == classes)/nrow(Ztest)*100
    }
    
    Pg  <- c( Pg, Pgi )
    Vip <- VIP(pls.fit,opt.comp=opt.comp)
    VIP.index <- which (as.matrix(Vip) < VIP.threshold)  
    if(length(VIP.index)<= (ncomp +1)) {
      VIP.index <- sort(Vip,decreasing=FALSE, index.return = T)$ix [1:ncomp]
    }
    is.selected[variables[VIP.index]] <- F
    variables     <- which( is.selected ) 
    Variable.list <- c(Variable.list, list(variables)) 
    Zcal  <- Zcal[,VIP.index]
    Ztest <- Ztest[,VIP.index]
    indd  <- unique( which(apply(Zcal, 2, var)==0),which(apply(Ztest, 2, var)==0))
    Zcal  <- Zcal[, -indd] 
    Ztest <- Ztest[, -indd] 
    if( ncol(Zcal) <= ncomp+1 ){  # terminates if less than 5 variables remain
      terminated <- TRUE
    } 
  }
  opt.iter <- which.min(Pg)
  bve.selection <- Variable.list[[opt.iter]] 
  return(list(bve.selection=bve.selection))
}
