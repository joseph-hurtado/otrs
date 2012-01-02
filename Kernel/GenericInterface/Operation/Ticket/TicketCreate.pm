# --
# Kernel/GenericInterface/Operation/Ticket/TicketCreate.pm - GenericInterface Ticket TicketCreate operation backend
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: TicketCreate.pm,v 1.18 2012-01-02 23:27:14 cr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::Ticket::TicketCreate;

use strict;
use warnings;

use Kernel::GenericInterface::Operation::Ticket::Common;
use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.18 $) [1];

=head1 NAME

Kernel::GenericInterface::Operation::Ticket::TicketCreate - GenericInterface Ticket TicketCreate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (
        qw(
        DebuggerObject ConfigObject MainObject LogObject TimeObject DBObject EncodeObject
        WebserviceID
        )
        )
    {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{TicketCommonObject}
        = Kernel::GenericInterface::Operation::Ticket::Common->new( %{$Self} );

    $Self->{Config} = $Self->{ConfigObject}->Get('GenericInterface::Operation::TicketCreate');

    return $Self;
}

=item Run()

perform TicketCreate Operation. This will return the created ticket number.

    my $Result = $OperationObject->Run(
        Data => {
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketID    => 123,                     # Ticket  ID number in OTRS (help desk system)
            ArticleID   => 43,                      # Article ID number in OTRS (help desk system)
            Error => {                              # should not return errors
                    ErrorCode    => 'Ticket.Create.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserLogin)) {
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: $Needed parameter is missing!",
            );
        }
    }

    # check needed hashes
    for my $Needed (qw(Ticket Article)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: $Needed parameter is missing or not valid!",
            );
        }
    }

    # check optional array/hashes
    for my $Optional (qw(DynamicField Attachment)) {
        if (
            defined $Param{Data}->{$Optional}
            && !IsHashRefWithData( $Param{Data}->{$Optional} )
            && !IsArrayRefWithData( $Param{Data}->{$Optional} )
            )
        {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: $Optional parameter is missing or not valid!",
            );
        }
    }

    # isolate ticket parameter
    my $Ticket = $Param{Data}->{Ticket};

    # remove leading and trailing spaces
    for my $Attribute ( keys %{$Ticket} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Ticket->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Ticket->{$Attribute} =~ s{\s+\z}{};
        }
    }
    if ( IsHashRefWithData( $Ticket->{PendingTime} ) ) {
        for my $Attribute ( keys %{ $Ticket->{PendingTime} } ) {
            if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

                #remove leading spaces
                $Ticket->{PendingTime}->{$Attribute} =~ s{\A\s+}{};

                #remove trailing spaces
                $Ticket->{PendingTime}->{$Attribute} =~ s{\s+\z}{};
            }
        }
    }

    # check Ticket attribute values
    my $TicketCheck = $Self->_CheckTicket( Ticket => $Ticket );

    if ( !$TicketCheck->{Success} ) {
        return $Self->{TicketCommonObject}->ReturnError( %{$TicketCheck} );
    }

    # isolate Article parameter
    my $Article = $Param{Data}->{Article};

    # remove leading and trailing spaces
    for my $Attribute ( keys %{$Article} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Article->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Article->{$Attribute} =~ s{\s+\z}{};
        }
    }
    if ( IsHashRefWithData( $Article->{OrigHeader} ) ) {
        for my $Attribute ( keys %{ $Article->{OrigHeader} } ) {
            if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

                #remove leading spaces
                $Article->{OrigHeader}->{$Attribute} =~ s{\A\s+}{};

                #remove trailing spaces
                $Article->{OrigHeader}->{$Attribute} =~ s{\s+\z}{};
            }
        }
    }

    # check attributes that can be gather by sysconfig
    if ( !$Article->{AutoResponseType} ) {
        $Article->{AutoResponseType} = $Self->{Config}->{AutoResponseType} || '';
    }
    if ( !$Article->{ArticleTypeID} && !$Article->{ArticleType} ) {
        $Article->{ArticleType} = $Self->{Config}->{ArticleType} || '';
    }
    if ( !$Article->{SenderTypeID} && !$Article->{SenderType} ) {
        $Article->{SenderType} = $Self->{Config}->{SenderType} || '';
    }
    if ( !$Article->{HistoryType} ) {
        $Article->{HistoryType} = $Self->{Config}->{HistoryType} || '';
    }
    if ( !$Article->{HistoryComment} ) {
        $Article->{HistoryComment} = $Self->{Config}->{HistoryComment} || '';
    }

    # check Article attribute values
    my $ArticleCheck = $Self->_CheckArticle( Article => $Article );

    if ( !$ArticleCheck->{Success} ) {
        if ( !$ArticleCheck->{ErrorCode} ) {
            return {
                Success => 0,
                %{$ArticleCheck},
                }
        }
        return $Self->{TicketCommonObject}->ReturnError( %{$ArticleCheck} );
    }

    # isolate DynamicField parameter
    my $DynamicField = $Param{Data}->{DynamicField};

    # homologate imput to array
    my @DynamicFieldList;
    if ( ref $DynamicField eq 'HASH' ) {
        push @DynamicFieldList, $DynamicField;
    }
    else {
        @DynamicFieldList = @{$DynamicField};
    }

    # check DynamicField internal structure
    for my $DynamicFieldItem (@DynamicFieldList) {
        if ( !IsHashRefWithData($DynamicFieldItem) ) {
            return {
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->DynamicField parameter is invalid!",
            };
        }

        # remove leading and trailing spaces
        for my $Attribute ( keys %{$DynamicFieldItem} ) {
            if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

                #remove leading spaces
                $DynamicFieldItem->{$Attribute} =~ s{\A\s+}{};

                #remove trailing spaces
                $DynamicFieldItem->{$Attribute} =~ s{\s+\z}{};
            }
        }

        # check DynamicField attribute values
        my $DynamicFieldCheck = $Self->_CheckDynamicField( DynamicField => $DynamicFieldItem );

        if ( !$DynamicFieldCheck->{Success} ) {
            return $Self->{TicketCommonObject}->ReturnError( %{$DynamicFieldCheck} );
        }
    }

    # isolate Attachment parameter
    my $Attachment = $Param{Data}->{Attachment};

    # homologate imput to array
    my @AttachmentList;
    if ( ref $Attachment eq 'HASH' ) {
        push @AttachmentList, $Attachment;
    }
    else {
        @AttachmentList = @{$Attachment};
    }

    # check Attachment internal structure
    for my $AttachmentItem (@AttachmentList) {
        if ( !IsHashRefWithData($AttachmentItem) ) {
            return {
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->Attachment parameter is invalid!",
            };
        }

        # remove leading and trailing spaces
        for my $Attribute ( keys %{$AttachmentItem} ) {
            if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

                #remove leading spaces
                $AttachmentItem->{$Attribute} =~ s{\A\s+}{};

                #remove trailing spaces
                $AttachmentItem->{$Attribute} =~ s{\s+\z}{};
            }
        }

        # check Attachment attribute values
        my $AttachmentCheck = $Self->_CheckAttachment( Attachment => $AttachmentItem );

        if ( !$AttachmentCheck->{Success} ) {
            return $Self->{TicketCommonObject}->ReturnError( %{$AttachmentCheck} );
        }
    }

    return {
        Success => 1,
        Data    => {
            Test => 'Test OK',
        },
    };
}

=begin Internal:

=item _CheckTicket()

checks if the given ticket parameters are valid.

    my $TicketCheck = $OperationObject->_CheckTicket(
        Ticket => $Ticket,                          # all ticket parameters
    );

    returns:

    $TicketCheck = {
        Success => 1,                               # if everething is OK
    }

    $TicketCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckTicket {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};

    # check ticket internally
    for my $Needed (qw(Title CustomerUser)) {
        if ( !$Ticket->{$Needed} ) {
            return {
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: Ticket->$Needed parameter is missing!",
            };
        }
    }

    # check Ticket->CustomerUser
    if ( !$Self->{TicketCommonObject}->ValidateCustomer( %{$Ticket} ) ) {
        return {
            ErrorCode => 'TicketCreate.InvalidParameter',
            ErrorMessage =>
                "TicketCreate: Ticket->CustomerUser parameter is invalid!",
        };
    }

    # check Ticket->Queue
    if ( !$Ticket->{QueueID} && !$Ticket->{Queue} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->QueueID or Ticket->Queue parameter is required!",
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateQueue( %{$Ticket} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->QueueID or Ticket->Queue parameter is invalid!",
        };
    }

    # check Ticket->Lock
    if ( !$Ticket->{LockID} && !$Ticket->{Lock} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->LockID or Ticket->Lock parameter is required!",
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateLock( %{$Ticket} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->LockID or Ticket->Lock parameter is invalid!",
        };
    }

    # check Ticket->Type
    # Ticket type could be required or not depending on sysconfig option
    if (
        !$Ticket->{TypeID}
        && !$Ticket->{Type}
        && $Self->{ConfigObject}->Get('Ticket::Type')
        )
    {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->TypeID or Ticket->Type parameter is required"
                . " by sysconfig option!",
        };
    }
    if ( $Ticket->{TypeID} || $Ticket->{Type} ) {
        if ( !$Self->{TicketCommonObject}->ValidateType( %{$Ticket} ) ) {
            return {
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->TypeID or Ticket->Type parameter is invalid!",
            };
        }
    }

    # check Ticket->Service
    # Ticket service could be required or not depending on sysconfig option
    if (
        !$Ticket->{ServiceID}
        && !$Ticket->{Service}
        && $Self->{ConfigObject}->Get('Ticket::Service')
        )
    {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->ServiceID or Ticket->Service parameter is"
                . "  required by sysconfig option!",
        };
    }
    if ( $Ticket->{ServiceID} || $Ticket->{Service} ) {
        if ( !$Self->{TicketCommonObject}->ValidateService( %{$Ticket} ) ) {
            return {
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->ServiceID or Ticket->Service parameter is invalid!",
            };
        }
    }

    # check Ticket->SLA
    if ( $Ticket->{SLAID} || $Ticket->{SLA} ) {
        if ( !$Self->{TicketCommonObject}->ValidateSLA( %{$Ticket} ) ) {
            return {
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->SLAID or Ticket->SLA parameter is invalid!",
            };
        }
    }

    # check Ticket->State
    if ( !$Ticket->{StateID} && !$Ticket->{State} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->StateID or Ticket->State parameter is required!",
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateState( %{$Ticket} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->StateID or Ticket->State parameter is invalid!",
        };
    }

    # check Ticket->Priority
    if ( !$Ticket->{PriorityID} && !$Ticket->{Priority} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->PriorityID or Ticket->Priority parameter is"
                . " required!",
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidatePriority( %{$Ticket} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->PriorityID or Ticket->Priority parameter is"
                . " invalid!",
        };
    }

    # check Ticket->Owner
    if ( !$Ticket->{OwnerID} && !$Ticket->{Owner} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->OwnerID or Ticket->Owner parameter is required!",
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateOwner( %{$Ticket} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->OwnerID or Ticket->Owner parameter is invalid!",
        };
    }

    # check Ticket->Responsible
    if ( $Ticket->{ResponsibleID} || $Ticket->{Responsible} ) {
        if ( !$Self->{TicketCommonObject}->ValidateResponsible( %{$Ticket} ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Ticket->ResponsibleID or Ticket->Responsible"
                    . " parameter is invalid!",
            };
        }
    }

    # check Ticket->PendingTime
    if ( $Ticket->{PendingTime} ) {
        if ( !$Self->{TicketCommonObject}->ValidatePendingTime( %{$Ticket} ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Ticket->PendingTimne parameter is invalid!",
            };
        }
    }

    # if everything is OK then return Success
    return {
        Success => 1,
        }
}

=item _CheckArticle()

checks if the given article parameter is valid.

    my $ArticleCheck = $OperationObject->_CheckArticle(
        Article => $Article,                        # all article parameters
    );

    returns:

    $ArticleCheck = {
        Success => 1,                               # if everething is OK
    }

    $ArticleCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckArticle {
    my ( $Self, %Param ) = @_;

    my $Article = $Param{Article};

    # check ticket internally
    for my $Needed (qw(Subject Body AutoResponseType)) {
        if ( !$Article->{$Needed} ) {
            return {
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: Article->$Needed parameter is missing!",
            };
        }
    }

    # check Article->AutoResponseType
    if ( !$Article->{AutoResponseType} ) {

        # return internal server error
        return {
            ErrorMessage => "TicketCreate: Article->AutoResponseType parameter is required and"
                . " Sysconfig ArticleTypeID setting could not be read!"
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateAutoResponseType( %{$Article} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Article->AutoResponseType parameter is invalid!",
        };
    }

    # check Article->ArticleType
    if ( !$Article->{ArticleTypeID} && !$Article->{ArticleType} ) {

        # return internal server error
        return {
            ErrorMessage => "TicketCreate: Article->ArticleTypeID or Article->ArticleType parameter"
                . " is required and Sysconfig ArticleTypeID setting could not be read!"
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateArticleType( %{$Article} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Article->ArticleTypeID or Article->ArticleType parameter"
                . " is invalid!",
        };
    }

    # check Article->SenderType
    if ( !$Article->{SenderTypeID} && !$Article->{SenderType} ) {

        # return internal server error
        return {
            ErrorMessage => "TicketCreate: Article->SenderTypeID or Article->SenderType parameter"
                . " is required and Sysconfig SenderTypeID setting could not be read!"
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateSenderType( %{$Article} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Article->SenderTypeID or Ticket->SenderType parameter"
                . " is invalid!",
        };
    }

    # check Article->ContentType vs Article->MimeType and Article->Charset
    if ( !$Article->{ContentType} && !$Article->{MimeType} && !$Article->{Charset} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Article->ContentType or Ticket->MimeType and"
                . " Article->Charset parameters are required!",
        };
    }

    if ( $Article->{MimeType} && !$Article->{Charset} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Article->Charset is required!",
        };
    }

    if ( $Article->{Charset} && !$Article->{MimeType} ) {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Article->MimeType is required!",
        };
    }

    # check Article->MimeType
    if ( $Article->{MimeType} ) {

        $Article->{MimeType} = lc $Article->{MimeType};

        if ( !$Self->{TicketCommonObject}->ValidateMimeType( %{$Article} ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Article->MimeType is invalid!",
            };
        }
    }

    # check Article->MimeType
    if ( $Article->{Charset} ) {

        $Article->{Charset} = lc $Article->{Charset};

        if ( !$Self->{TicketCommonObject}->ValidateCharset( %{$Article} ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Article->Charset is invalid!",
            };
        }
    }

    # check Article->ContentType
    if ( $Article->{ContentType} ) {

        $Article->{ContentType} = lc $Article->{ContentType};

        # check Charset part
        my $Charset = '';
        if ( $Article->{ContentType} =~ /charset=/i ) {
            $Charset = $Article->{ContentType};
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;
        }

        if ( !$Self->{TicketCommonObject}->ValidateCharset( Charset => $Charset ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Article->ContentType is invalid!",
            };
        }

        # check MimeType part
        my $MimeType = '';
        if ( $Article->{ContentType} =~ /^(\w+\/\w+)/i ) {
            $MimeType = $1;
            $MimeType =~ s/"|'//g;
        }

        if ( !$Self->{TicketCommonObject}->ValidateMimeType( MimeType => $MimeType ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Article->ContentType is invalid!",
            };
        }
    }

    # check Article->HistoryType
    if ( !$Article->{HistoryType} ) {

        # return internal server error
        return {
            ErrorMessage => "TicketCreate: Article-> HistoryType is required and Sysconfig"
                . " HistoryType setting could not be read!"
        };
    }
    if ( !$Self->{TicketCommonObject}->ValidateHistoryType( %{$Article} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Article->HistoryType parameter is invalid!",
        };
    }

    # check Article->HistoryComment
    if ( !$Article->{HistoryComment} ) {

        # return internal server error
        return {
            ErrorMessage => "TicketCreate: Article->HistoryComment is required and Sysconfig"
                . " HistoryComment setting could not be read!"
        };
    }

    # check Article->TimeUnit
    # TimeUnit could be required or not depending on sysconfig option
    if (
        !$Article->{TimeUnit}
        && $Self->{ConfigObject}->{'Ticket::Frontend::AccountTime'}
        && $Self->{ConfigObject}->{'Ticket::Frontend::NeedAccountedTime'}
        )
    {
        return {
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Article->TimeUnit is required by sysconfig option!",
        };
    }
    if ( $Article->{TimeUnit} ) {
        if ( !$Self->{TicketCommonObject}->ValidateTimeUnit( %{$Article} ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Article->TimeUnit parameter is invalid!",
            };
        }
    }

    # check Article->NoAgentNotify
    if ( $Article->{NoAgentNotify} && $Article->{NoAgentNotify} ne '1' ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Article->NoAgent parameter is invalid!",
        };
    }

    # check Article array parameters
    for my $Attribute (
        qw( ForceNotificationToUserID ExcludeNotificationToUserID ExcludeMuteNotificationToUserID )
        )
    {
        if ( defined $Article->{$Attribute} ) {

            # check structure
            if ( IsHashRefWithData( $Article->{$Attribute} ) ) {
                return {
                    ErrorCode    => 'TicketCreate.InvalidParameter',
                    ErrorMessage => "TicketCreate: Article->$Attribute parameter is invalid!",
                };
            }
            else {
                if ( !IsArrayRefWithData( $Article->{$Attribute} ) ) {
                    $Article->{$Attribute} = [ $Article->{$Attribute} ];
                }
                for my $UserID ( @{ $Article->{$Attribute} } ) {
                    if ( !$Self->{TicketCommonObject}->ValidateUserID( UserID => $UserID ) ) {
                        return {
                            ErrorCode    => 'TicketCreate.InvalidParameter',
                            ErrorMessage => "TicketCreate: Article->$Attribute UserID=$UserID"
                                . " parameter is invalid!",
                        };
                    }
                }
            }
        }
    }

    # if everything is OK then return Success
    return {
        Success => 1,
    };
}

=item _CheckDynamicField()

checks if the given dynamic field parameter is valid.

    my $DynamicFieldCheck = $OperationObject->_CheckDynamicField(
        DynamicField => $DynamicField,              # all dynamic field parameters
    );

    returns:

    $DynamicFieldCheck = {
        Success => 1,                               # if everething is OK
    }

    $DynamicFieldCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckDynamicField {
    my ( $Self, %Param ) = @_;

    my $DynamicField = $Param{DynamicField};

    # check DynamicField itm internally
    for my $Needed (qw(Name Value)) {
        if ( !$DynamicField->{$Needed} ) {
            return {
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: DynamicField->$Needed  parameter is missing!",
            };
        }
    }

    # check DynamicField->Name
    if ( !$Self->{TicketCommonObject}->ValidateDynamicFieldName( %{$DynamicField} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: DynamicField->Name parameter is invalid!",
        };
    }

    # check DynamicField->Value
    if ( !$Self->{TicketCommonObject}->ValidateDynamicFieldValue( %{$DynamicField} ) ) {
        return {
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: DynamicField->Value parameter is invalid!",
        };
    }

    # if everything is OK then return Success
    return {
        Success => 1,
    };
}

=item _CheckAttachment()

checks if the given attachment parameter is valid.

    my $AttachmentCheck = $OperationObject->_CheckAttachment(
        Attachment => $Attachment,                  # all attachment parameters
    );

    returns:

    $AttachmentCheck = {
        Success => 1,                               # if everething is OK
    }

    $AttachmentCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckAttachment {
    my ( $Self, %Param ) = @_;

    my $Attachment = $Param{Attachment};

    # check DynamicField itm internally
    for my $Needed (qw(Content ContentType Filename)) {
        if ( !$Attachment->{$Needed} ) {
            return {
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: Attachment->$Needed  parameter is missing!",
            };
        }
    }

    # check Article->ContentType
    if ( $Attachment->{ContentType} ) {

        $Attachment->{ContentType} = lc $Attachment->{ContentType};

        # check Charset part
        my $Charset = '';
        if ( $Attachment->{ContentType} =~ /charset=/i ) {
            $Charset = $Attachment->{ContentType};
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;
        }

        if ( !$Self->{TicketCommonObject}->ValidateCharset( Charset => $Charset ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Attahcment->ContentType is invalid!",
            };
        }

        # check MimeType part
        my $MimeType = '';
        if ( $Attachment->{ContentType} =~ /^(\w+\/\w+)/i ) {
            $MimeType = $1;
            $MimeType =~ s/"|'//g;
        }

        if ( !$Self->{TicketCommonObject}->ValidateMimeType( MimeType => $MimeType ) ) {
            return {
                ErrorCode    => 'TicketCreate.InvalidParameter',
                ErrorMessage => "TicketCreate: Attachment->ContentType is invalid!",
            };
        }
    }

    # if everything is OK then return Success
    return {
        Success => 1,
    };
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

=head1 VERSION

$Revision: 1.18 $ $Date: 2012-01-02 23:27:14 $

=cut