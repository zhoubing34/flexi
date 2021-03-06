!=================================================================================================================================
! Copyright (c) 2016  Prof. Claus-Dieter Munz 
! This file is part of FLEXI, a high-order accurate framework for numerically solving PDEs with discontinuous Galerkin methods.
! For more information see https://www.flexi-project.org and https://nrg.iag.uni-stuttgart.de/
!
! FLEXI is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
! as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
!
! FLEXI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with FLEXI. If not, see <http://www.gnu.org/licenses/>.
!=================================================================================================================================


!==================================================================================================================================
!> Changes a 2D or 3D Tensor Product Lagrange Points of Lagrange Basis of degree NIn to
!> Lagrange points of a Lagrange Basis NOut, using two
!> arbitrary point disributions xi_In(0:NIn) and xi_Out(0:NOut)
!==================================================================================================================================
MODULE MOD_ChangeBasis
! MODULES
IMPLICIT NONE
PRIVATE
!----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------

! Public Part ----------------------------------------------------------------------------------------------------------------------
INTERFACE ChangeBasis3D
  MODULE PROCEDURE ChangeBasis3D_Single
  MODULE PROCEDURE ChangeBasis3D_Mult
END INTERFACE
!
INTERFACE ChangeBasis2D
  MODULE PROCEDURE ChangeBasis2D_Single
  MODULE PROCEDURE ChangeBasis2D_Mult
END INTERFACE

INTERFACE ChangeBasis3D_XYZ
  MODULE PROCEDURE ChangeBasis3D_XYZ
END INTERFACE

PUBLIC :: ChangeBasis3D
PUBLIC :: ChangeBasis2D
PUBLIC :: ChangeBasis3D_XYZ
!==================================================================================================================================

CONTAINS


!==================================================================================================================================
!> Interpolate a 3D tensor product Lagrange basis defined by (NIn+1) 1D interpolation point positions xi_In(0:NIn)
!> to another 3D tensor product node positions (number of nodes NOut+1)
!> defined by (NOut+1) interpolation point  positions xi_Out(0:NOut)
!>  xi is defined in the 1DrefElem xi=[-1,1]. 
!>  _Mult means that more than data fields containing more than one element can be processed
!==================================================================================================================================
SUBROUTINE ChangeBasis3D_Mult(nVar,nElems,NIn,NOut,Vdm,UIn,UOut,addToOutput)
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: nVar                                    !< Number of variables
INTEGER,INTENT(IN)  :: nElems                                  !< Number of elements
INTEGER,INTENT(IN)  :: NIn                                     !< Input polynomial degree, no. of points = NIn+1
INTEGER,INTENT(IN)  :: NOut                                    !< Output polynomial degree, no. of points = NOut+1
                                   
REAL,INTENT(IN)     :: UIn(nVar,0:NIn,0:NIn,0:NIn,nElems)      !< Input field, dimensions must match nVar,NIn and nElems
REAL,INTENT(IN)     :: Vdm(0:NOut,0:NIn)                       !< 1D Vandermonde In -> Out
REAL,INTENT(INOUT)  :: UOut(nVar,0:NOut,0:NOut,0:NOut,nElems)  !< Output field
LOGICAL,INTENT(IN)  :: addToOutput                             !< TRUE: add the result to 'in' state of Uout, FALSE: overwrite Uout
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: iI,jI,kI,iO,jO,kO,iElem,a,b,nVar2
REAL,ALLOCATABLE    :: UBuf1(:,:,:,:),UBuf2(:,:,:,:)
!==================================================================================================================================
nVar2=nVar*nElems
IF(nVar2.GT.2*nVar)THEN
  ALLOCATE(UBuf2(nVar2,0:NIn,0:NIn,0:NIn))
  ALLOCATE(UBuf1(nVar2,0:NOut,0:NIn,0:NIn))

  ! pack solution
  DO iElem=1,nElems
    a=nVar*(iElem-1)+1
    b=nVar*iElem
    DO kI=0,NIn; DO jI=0,NIn; DO iI=0,NIn
      Ubuf2(a:b,iI,jI,kI)=UIn(:,iI,jI,kI,iElem)
    END DO; END DO; END DO
  END DO

  ! first direction iI
  DO kI=0,NIn; DO jI=0,NIn
    DO iO=0,NOut
      UBuf1(:,iO,jI,kI)=Vdm(iO,0)*Ubuf2(:,0,jI,kI)
    END DO
    DO iI=1,NIn
      DO iO=0,NOut
        UBuf1(:,iO,jI,kI)=UBuf1(:,iO,jI,kI)+Vdm(iO,iI)*Ubuf2(:,iI,jI,kI)
      END DO
    END DO
  END DO; END DO

  DEALLOCATE(Ubuf2)
  ALLOCATE(UBuf2(nVar2,0:NOut,0:NOut,0:NIn))

  ! second direction jI
  DO kI=0,NIn
    DO jO=0,NOut; DO iO=0,NOut
      UBuf2(:,iO,jO,kI)=Vdm(jO,0)*UBuf1(:,iO,0,kI)
    END DO; END DO
    DO jI=1,NIn
      DO jO=0,NOut; DO iO=0,NOut
        UBuf2(:,iO,jO,kI)=UBuf2(:,iO,jO,kI)+Vdm(jO,jI)*UBuf1(:,iO,jI,kI)
      END DO; END DO
    END DO
  END DO

  DEALLOCATE(Ubuf1)
  ALLOCATE(UBuf1(nVar2,0:NOut,0:NOut,0:NOut))

  ! last direction kI
  DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
    Ubuf1(:,iO,jO,kO)=Vdm(kO,0)*UBuf2(:,iO,jO,0)
  END DO; END DO; END DO
  DO kI=1,NIn
    DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
      Ubuf1(:,iO,jO,kO)=Ubuf1(:,iO,jO,kO)+Vdm(kO,kI)*UBuf2(:,iO,jO,kI)
    END DO; END DO; END DO
  END DO

  ! unpack solution
  IF(addToOutput)THEN
    DO iElem=1,nElems
      a=nVar*(iElem-1)+1
      b=nVar*iElem
      DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
        UOut(:,iO,jO,kO,iElem)=UOut(:,iO,jO,kO,iElem)+Ubuf1(a:b,iO,jO,kO)
      END DO; END DO; END DO
    END DO
  ELSE
    DO iElem=1,nElems
      a=nVar*(iElem-1)+1
      b=nVar*iElem
      DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
        UOut(:,iO,jO,kO,iElem)=Ubuf1(a:b,iO,jO,kO)
      END DO; END DO; END DO
    END DO
  END IF
  DEALLOCATE(UBuf1,Ubuf2)

ELSE

  ALLOCATE(UBuf1(nVar,0:NOut,0:NIn,0:NIn))
  ALLOCATE(UBuf2(nVar,0:NOut,0:NOut,0:NIn))
  DO iElem=1,nElems
    ! first direction iI
    DO kI=0,NIn; DO jI=0,NIn
      DO iO=0,NOut
        UBuf1(:,iO,jI,kI)=Vdm(iO,0)*UIn(:,0,jI,kI,iElem)
      END DO
      DO iI=1,NIn
        DO iO=0,NOut
          UBuf1(:,iO,jI,kI)=UBuf1(:,iO,jI,kI)+Vdm(iO,iI)*UIn(:,iI,jI,kI,iElem)
        END DO
      END DO
    END DO; END DO
    ! second direction jI
    DO kI=0,NIn
      DO jO=0,NOut; DO iO=0,NOut
        UBuf2(:,iO,jO,kI)=Vdm(jO,0)*UBuf1(:,iO,0,kI)
      END DO; END DO
      DO jI=1,NIn
        DO jO=0,NOut; DO iO=0,NOut
          UBuf2(:,iO,jO,kI)=UBuf2(:,iO,jO,kI)+Vdm(jO,jI)*UBuf1(:,iO,jI,kI)
        END DO; END DO
      END DO
    END DO
    ! last direction kI
    IF(addToOutput)THEN
      DO kI=0,NIn
        DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
          UOut(:,iO,jO,kO,iElem)=UOut(:,iO,jO,kO,iElem)+Vdm(kO,kI)*UBuf2(:,iO,jO,kI)
        END DO; END DO; END DO
      END DO
    ELSE
      DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
        UOut(:,iO,jO,kO,iElem)=Vdm(kO,0)*UBuf2(:,iO,jO,0)
      END DO; END DO; END DO
      DO kI=1,NIn
        DO kO=0,NOut; DO jO=0,NOut; DO iO=0,NOut
          UOut(:,iO,jO,kO,iElem)=UOut(:,iO,jO,kO,iElem)+Vdm(kO,kI)*UBuf2(:,iO,jO,kI)
        END DO; END DO; END DO
      END DO
    END IF
  END DO
  DEALLOCATE(UBuf1,Ubuf2)

END IF
END SUBROUTINE ChangeBasis3D_Mult
!==================================================================================================================================
!> interpolate a 3D tensor product Lagrange basis defined by (NIn+1) 1D interpolation point positions xi_In(0:NIn)
!> to another 3D tensor product node positions (number of nodes NOut+1)
!> defined by (NOut+1) interpolation point  positions xi_Out(0:NOut)
!>  xi is defined in the 1DrefElem xi=[-1,1]. 
!>  _Single is only suitable for one tensor product element
!==================================================================================================================================
SUBROUTINE ChangeBasis3D_Single(Dim1,NIn,NOut,Vdm,X3D_In,X3D_Out)
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: Dim1                                    !< Number of variables
INTEGER,INTENT(IN)  :: NIn                                     !< Input polynomial degree, no. of points = NIn+1
INTEGER,INTENT(IN)  :: NOut                                    !< Output polynomial degree, no. of points = NOut+1
REAL,INTENT(IN)     :: X3D_In(1:Dim1,0:NIn,0:NIn,0:NIn)        !< Input field, dimensions must match Dim1,NIn
REAL,INTENT(OUT)    :: X3D_Out(1:Dim1,0:NOut,0:NOut,0:NOut)    !< Output field, dimensions must match Dim1,NOut
REAL,INTENT(IN)     :: Vdm(0:NOut,0:NIn)                       !< 1D Vandermonde In -> Out
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: iNIn,jNIn,kNIn,iN_Out,jN_Out,kN_Out
REAL                :: X3D_Buf1(1:Dim1,0:NOut,0:NIn,0:NIn)  ! first intermediate results from 1D interpolations
REAL                :: X3D_Buf2(1:Dim1,0:NOut,0:NOut,0:NIn) ! second intermediate results from 1D interpolations
!==================================================================================================================================
X3D_buf1=0.
! first direction iNIn
DO kNIn=0,NIn
  DO jNIn=0,NIn
    DO iNIn=0,NIn
      DO iN_Out=0,NOut
        X3D_Buf1(:,iN_Out,jNIn,kNIn)=X3D_Buf1(:,iN_Out,jNIn,kNIn)+Vdm(iN_Out,iNIn)*X3D_In(:,iNIn,jNIn,kNIn)
      END DO
    END DO
  END DO
END DO
X3D_buf2=0.
! second direction jNIn
DO kNIn=0,NIn
  DO jNIn=0,NIn
    DO jN_Out=0,NOut
      DO iN_Out=0,NOut
        X3D_Buf2(:,iN_Out,jN_Out,kNIn)=X3D_Buf2(:,iN_Out,jN_Out,kNIn)+Vdm(jN_Out,jNIn)*X3D_Buf1(:,iN_Out,jNIn,kNIn)
      END DO
    END DO
  END DO
END DO
X3D_Out=0.
! last direction kNIn
DO kNIn=0,NIn
  DO kN_Out=0,NOut
    DO jN_Out=0,NOut
      DO iN_Out=0,NOut
        X3D_Out(:,iN_Out,jN_Out,kN_Out)=X3D_Out(:,iN_Out,jN_Out,kN_Out)+Vdm(kN_Out,kNIn)*X3D_Buf2(:,iN_Out,jN_Out,kNIn)
      END DO
    END DO
  END DO
END DO
END SUBROUTINE ChangeBasis3D_Single



!==================================================================================================================================
!> Interpolate a 2D tensor product Lagrange basis defined by (NIn+1) 1D interpolation point positions xi_In(0:NIn)
!> to another 2D tensor product node positions (number of nodes NOut+1)
!> defined by (NOut+1) interpolation point  positions xi_Out(0:NOut)
!>  xi is defined in the 1DrefElem xi=[-1,1. ]
!>  _Mult means that more than data fields containing more than one element can be processed
!==================================================================================================================================
SUBROUTINE ChangeBasis2D_Mult(nVar,firstSideID,lastSideID,iStart,iEnd,NIn,NOut,Vdm,UIn,UOut,addToOutput)
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: nVar                                            !< Number of variables
INTEGER,INTENT(IN)  :: firstSideID                                     !< lower bound defining the size of the field
INTEGER,INTENT(IN)  :: lastSideID                                      !< upper bound defining the size of the field
INTEGER,INTENT(IN)  :: iStart                                          !< lower bound where ChangeBasis2D operates
INTEGER,INTENT(IN)  :: iEnd                                            !< upper bound where ChangeBasis2D operates
INTEGER,INTENT(IN)  :: NIn                                             !< Input polynomial degree, no. of points = NIn+1
INTEGER,INTENT(IN)  :: NOut                                            !< Output polynomial degree, no. of points = NOut+1
REAL,INTENT(IN)     :: Vdm(0:NOut,0:NIn)                               !< 1D Vandermonde In -> Out
REAL,INTENT(IN)     :: UIn(nVar,0:NIn,0:NIn,firstSideID:lastSideID)    !< Input field
REAL,INTENT(INOUT)  :: UOut(nVar,0:NOut,0:NOut,firstSideID:lastSideID) !< Output field
LOGICAL,INTENT(IN)  :: addToOutput                                     !< TRUE: add the result to 'in' state of Uout, FALSE: overwrite Uout

!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: iI,jI,iO,jO,iSide,a,b,nVar2,nLocSides
REAL,ALLOCATABLE    :: UBuf1(:,:,:),UBuf2(:,:,:)
!==================================================================================================================================
IF(iEnd.LT.iStart) RETURN

nLocSides=iEnd-iStart+1
nVar2=nVar*nLocSides
IF(nVar2.GT.2*nVar)THEN
  ALLOCATE(UBuf2(nVar2,0:NIn,0:NIn))
  ALLOCATE(UBuf1(nVar2,0:NOut,0:NIn))
  ! pack solution
  DO iSide=iStart,iEnd
    a=nVar*(iSide-iStart)+1
    b=nVar*(iSide-iStart+1)
    DO jI=0,NIn; DO iI=0,NIn
      Ubuf2(a:b,iI,jI)=UIn(:,iI,jI,iSide)
    END DO; END DO
  END DO

  ! first direction iI
  DO jI=0,NIn
    DO iO=0,NOut
      UBuf1(:,iO,jI)=Vdm(iO,0)*Ubuf2(:,0,jI)
    END DO
    DO iI=1,NIn
      DO iO=0,NOut
        UBuf1(:,iO,jI)=UBuf1(:,iO,jI)+Vdm(iO,iI)*Ubuf2(:,iI,jI)
      END DO
    END DO
  END DO

  DEALLOCATE(UBuf2)
  ALLOCATE(UBuf2(nVar2,0:NOut,0:NOut))

  ! second direction jI
  DO jO=0,NOut; DO iO=0,NOut
    UBuf2(:,iO,jO)=Vdm(jO,0)*UBuf1(:,iO,0)
  END DO; END DO
  DO jI=1,NIn
    DO jO=0,NOut; DO iO=0,NOut
      UBuf2(:,iO,jO)=UBuf2(:,iO,jO)+Vdm(jO,jI)*UBuf1(:,iO,jI)
    END DO; END DO
  END DO

  ! unpack solution
  IF(addToOutput)THEN
    DO iSide=iStart,iEnd
      a=nVar*(iSide-iStart)+1
      b=nVar*(iSide-iStart+1)
      DO jO=0,NOut; DO iO=0,NOut
        UOut(:,iO,jO,iSide)=UOut(:,iO,jO,iSide)+Ubuf2(a:b,iO,jO)
      END DO; END DO
    END DO
  ELSE
    DO iSide=iStart,iEnd
      a=nVar*(iSide-iStart)+1
      b=nVar*(iSide-iStart+1)
      DO jO=0,NOut; DO iO=0,NOut
        UOut(:,iO,jO,iSide)=Ubuf2(a:b,iO,jO)
      END DO; END DO
    END DO
  END IF
  DEALLOCATE(UBuf1,UBuf2)

ELSE

  ALLOCATE(UBuf1(nVar,0:NOut,0:NIn))
  DO iSide=iStart,iEnd
    ! first direction iI
    DO jI=0,NIn
      DO iO=0,NOut
        UBuf1(:,iO,jI)=Vdm(iO,0)*UIn(:,0,jI,iSide)
      END DO
      DO iI=1,NIn
        DO iO=0,NOut
          UBuf1(:,iO,jI)=UBuf1(:,iO,jI)+Vdm(iO,iI)*UIn(:,iI,jI,iSide)
        END DO
      END DO
    END DO

    ! second direction jI
    IF(addToOutput)THEN
      DO jI=0,NIn
        DO jO=0,NOut; DO iO=0,NOut
          UOut(:,iO,jO,iSide)=UOut(:,iO,jO,iSide)+Vdm(jO,jI)*UBuf1(:,iO,jI)
        END DO; END DO
      END DO
    ELSE
      DO jO=0,NOut; DO iO=0,NOut
        UOut(:,iO,jO,iSide)=Vdm(jO,0)*UBuf1(:,iO,0)
      END DO; END DO
      DO jI=1,NIn
        DO jO=0,NOut; DO iO=0,NOut
          UOut(:,iO,jO,iSide)=UOut(:,iO,jO,iSide)+Vdm(jO,jI)*UBuf1(:,iO,jI)
        END DO; END DO
      END DO
    END IF

  END DO
  DEALLOCATE(UBuf1)
END IF
END SUBROUTINE ChangeBasis2D_Mult
!==================================================================================================================================
!> interpolate a 2D tensor product Lagrange basis defined by (NIn+1) 1D interpolation point positions xi_In(0:NIn)
!> to another 2D tensor product node positions (number of nodes NOut+1)
!> defined by (NOut+1) interpolation point  positions xi_Out(0:NOut)
!>  xi is defined in the 1DrefElem xi=[-1,1]. 
!>  _Single is only suitable for one tensor product element
!==================================================================================================================================
SUBROUTINE ChangeBasis2D_Single(Dim1,NIn,NOut,Vdm,X2D_In,X2D_Out)
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: Dim1                                    !< Number of variables
INTEGER,INTENT(IN)  :: NIn                                     !< Input polynomial degree, no. of points = NIn+1
INTEGER,INTENT(IN)  :: NOut                                    !< Output polynomial degree, no. of points = NOut+1
REAL,INTENT(IN)     :: X2D_In(1:Dim1,0:NIn,0:NIn)              !< Input field, dimensions must match Dim1,NIn
REAL,INTENT(OUT)    :: X2D_Out(1:Dim1,0:NOut,0:NOut)           !< Output field, dimensions must match Dim1,NOut
REAL,INTENT(IN)     :: Vdm(0:NOut,0:NIn)                       !< 1D Vandermonde In -> Out

!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: iNIn,jNIn,iN_Out,jN_Out
REAL                :: X2D_Buf1(1:Dim1,0:NOut,0:NIn)  ! first intermediate results from 1D interpolations
!==================================================================================================================================
X2D_buf1=0.
! first direction iNIn
DO jNIn=0,NIn
  DO iNIn=0,NIn
    DO iN_Out=0,NOut
      X2D_Buf1(:,iN_Out,jNIn)=X2D_Buf1(:,iN_Out,jNIn)+Vdm(iN_Out,iNIn)*X2D_In(:,iNIn,jNIn)
    END DO
  END DO
END DO
X2D_Out=0.
! second direction jNIn
DO jNIn=0,NIn
  DO jN_Out=0,NOut
    DO iN_Out=0,NOut
      X2D_Out(:,iN_Out,jN_Out)=X2D_Out(:,iN_Out,jN_Out)+Vdm(jN_Out,jNIn)*X2D_Buf1(:,iN_Out,jNIn)
    END DO
  END DO
END DO
END SUBROUTINE ChangeBasis2D_Single


!==================================================================================================================================
!> interpolate a 3D tensor product Lagrange basis defined by (NIn+1) 1D interpolation point positions xi_In(0:NIn)
!> to another 3D tensor product node positions (number of nodes NOut+1)
!> defined by (NOut+1) interpolation point  positions xi_Out(0:NOut) using DIFFERENT 1D Vdm matrices in the xi,eta, zeta directions
!>  xi is defined in the 1DrefElem xi=[-1,1]
!==================================================================================================================================
SUBROUTINE ChangeBasis3D_XYZ(Dim1,NIn,NOut,Vdm_xi,Vdm_eta,Vdm_zeta,X3D_In,X3D_Out)
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: Dim1                                    !< Number of variables
INTEGER,INTENT(IN)  :: NIn                                     !< Input polynomial degree, no. of points = NIn+1
INTEGER,INTENT(IN)  :: NOut                                    !< Output polynomial degree, no. of points = NOut+1
REAL,INTENT(IN)     :: X3D_In(1:Dim1,0:NIn,0:NIn,0:NIn)        !< Input field, dimensions must match Dim1,NIn
REAL,INTENT(OUT)    :: X3D_Out(1:Dim1,0:NOut,0:NOut,0:NOut)    !< Output field, dimensions must match Dim1,NOut
REAL,INTENT(IN)     :: Vdm_xi(0:NOut,0:NIn)                    !< 1D Vandermonde In -> Out xi direction
REAL,INTENT(IN)     :: Vdm_eta(0:NOut,0:NIn)                   !< 1D Vandermonde In -> Out eta direction
REAL,INTENT(IN)     :: Vdm_zeta(0:NOut,0:NIn)                  !< 1D Vandermonde In -> Out zeta direction

!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: iNIn,jNIn,kNIn,iN_Out,jN_Out,kN_Out
REAL                :: X3D_Buf1(1:Dim1,0:NOut,0:NIn,0:NIn)  ! first intermediate results from 1D interpolations
REAL                :: X3D_Buf2(1:Dim1,0:NOut,0:NOut,0:NIn) ! second intermediate results from 1D interpolations
!==================================================================================================================================
X3D_buf1=0.
! first direction iNIn
DO kNIn=0,NIn
  DO jNIn=0,NIn
    DO iNIn=0,NIn
      DO iN_Out=0,NOut
        X3D_Buf1(:,iN_Out,jNIn,kNIn)=X3D_Buf1(:,iN_Out,jNIn,kNIn)+Vdm_xi(iN_Out,iNIn)*X3D_In(:,iNIn,jNIn,kNIn)
      END DO
    END DO
  END DO
END DO
X3D_buf2=0.
! second direction jNIn
DO kNIn=0,NIn
  DO jNIn=0,NIn
    DO jN_Out=0,NOut
      DO iN_Out=0,NOut
        X3D_Buf2(:,iN_Out,jN_Out,kNIn)=X3D_Buf2(:,iN_Out,jN_Out,kNIn)+Vdm_eta(jN_Out,jNIn)*X3D_Buf1(:,iN_Out,jNIn,kNIn)
      END DO
    END DO
  END DO
END DO
X3D_Out=0.
! last direction kNIn
DO kNIn=0,NIn
  DO kN_Out=0,NOut
    DO jN_Out=0,NOut
      DO iN_Out=0,NOut
        X3D_Out(:,iN_Out,jN_Out,kN_Out)=X3D_Out(:,iN_Out,jN_Out,kN_Out)+Vdm_zeta(kN_Out,kNIn)*X3D_Buf2(:,iN_Out,jN_Out,kNIn)
      END DO
    END DO
  END DO
END DO
END SUBROUTINE ChangeBasis3D_XYZ

END MODULE MOD_ChangeBasis
